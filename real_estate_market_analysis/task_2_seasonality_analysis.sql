--данный запрос написан для анализа того же рынка, а именно для анализа сезонных тенденций в городах с целью выявления периодов с повышенной активностью продавцов и покупателей.
-- а также для оценки характеристики недвижимости в разные сезоны для планирования маркетинговых стратегий и выбора сроков выхода на рынок.
WITH limits AS ( 				--определение аномальных значения (выбросы) по значению перцентилей:
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit, 
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS (					--поиск id объявлений, которые не содержат выбросы:
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
),
announcement AS (						-- извлечение месяца и фильтрация
    SELECT rf.id,  
           EXTRACT (MONTH FROM first_day_exposition) AS month_of_publication, --извлечение месяца публикации
           EXTRACT(MONTH FROM first_day_exposition + (days_exposition :: integer)) AS month_of_sale, --извлечение месяца продажи
           last_price,
           total_area
    FROM real_estate.advertisement AS ra
    JOIN real_estate.flats AS rf ON ra.id = rf.id 
    WHERE rf.type_id = 'F8EM'						 --фильтрация для населенного пункта - город
        AND first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 		--фильтрация по изучаемым годам
        AND rf.id IN (SELECT id FROM filtered_id)  		--фильтрация объявлений без выбросов
),
month_metric_publication AS ( 				--расчет метрик по месяцам публикации
    SELECT 
        month_of_publication AS month,
        COUNT(*) AS pub_quantity,        --кол-во объявлений при публикации
        ROUND(AVG(last_price / total_area)) AS pub_avg_cost,      --средняя стоимость кв метра при публикации
        ROUND(AVG(total_area)::numeric, 1) AS pub_avg_area,       --средняя площадь при публикации
        round ((COUNT(*)::real / SUM(COUNT(*)) OVER () * 100)::NUMERIC, 2) AS pub_share   		--доля опубликовываемых объявлений от всех объявлений
    FROM announcement
    GROUP BY month_of_publication
),
month_metric_sale AS ( --расчет метрик по месяцам продажи
    SELECT 
        month_of_sale AS month,
        COUNT(*) AS sale_quantity, 			--кол-во объявлений при продаже
        ROUND(AVG(last_price / total_area)) AS sale_avg_cost, 		--средняя стоимость кв метра при продаже
        ROUND(AVG(total_area)::numeric, 1) AS sale_avg_area, 		--средняя площадь при продаже
        round ((COUNT(id)::real / SUM(COUNT(id)) OVER () * 100)::NUMERIC, 2) AS sale_share 		--доля снятых с публикации объявлений от всех
    FROM announcement AS a
    WHERE month_of_sale IS NOT NULL 
    GROUP BY month_of_sale
),
all_months AS (
    SELECT generate_series(1, 12) AS month 		--набор строк с номером месяца
)
SELECT 
    am.month,
   	p.pub_quantity,
    p.pub_avg_cost,
    p.pub_avg_area,
    p.pub_share,
    s.sale_quantity,
    s.sale_avg_cost,
    s.sale_avg_area,
    sale_share
FROM all_months AS am
LEFT JOIN month_metric_publication as p ON am.month = p.month
LEFT JOIN month_metric_sale AS s ON am.month = s.month
ORDER BY am.month;

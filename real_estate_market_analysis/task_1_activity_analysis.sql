--данный запрос написан для анализа рынка недвижимости Санкт-Петербурга и Лен.области и помогает спланировать бизнес-стратегию выхода на рынок
WITH category AS ( --категоризация объявлений и населенных пунктов
	SELECT ra.id,
			rf.rooms,
			rf.balcony,
			ra.last_price,
			rf.total_area,
	CASE 												--категоризация объявлений по дням нахождения в продаже
		WHEN days_exposition <= 30 THEN 'one_month'
		WHEN days_exposition <= 90 THEN 'one_or_three_month'
		WHEN days_exposition <= 180 THEN 'three_or_six_month'
		WHEN days_exposition >= 181 THEN 'more_than_six_months'
		WHEN days_exposition IS NULL THEN 'non_category'
	END AS days_category,
	CASE 
		WHEN rf.city_id = '6X8I' THEN 'Санкт-Петербург' 	--категоризация объявлений по названию населенного пункта
		ELSE 'ЛенОбл'
	END AS city_category 
	FROM real_estate.advertisement AS ra
	JOIN real_estate.flats AS rf ON ra.id = rf.id
	JOIN real_estate.city AS rc ON rf.city_id = rc.city_id
	WHERE first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31' 		--фильтрация объявлений по изучаемым годам 
		AND rf.total_area IS NOT NULL
		AND rf.type_id = 'F8EM'
),
limits AS (                                --определение аномальных значения (выбросов) по значению перцентилей 
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
filtered_id AS( 							--поиск id объявлений, которые не содержат выбросы:
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
        AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
)
SELECT 
    days_category,
    city_category,
    COUNT(*) AS quantity_apartments, -- количество объявлений
    round (AVG(last_price /total_area)) AS avg_cost_kv_metre, --средняя стоимость квадратного метра
    (COUNT(id)::real / SUM(COUNT(id)) OVER(PARTITION BY city_category) * 100)::numeric(4,2) AS total_adv_share, -- процент объявлений каждой категории внутри city_category
    round (AVG(total_area):: numeric, 1) AS avg_area, --средняя площадь квартир
    percentile_disc (0.5) WITHIN GROUP (ORDER BY rooms) AS quantity_rooms, -- медианное значение комнат
    percentile_disc (0.5) WITHIN GROUP (ORDER BY balcony) AS quantity_balcony --медианное значение балконов
FROM category AS c
WHERE id IN (SELECT id FROM filtered_id)
GROUP BY days_category, city_category
ORDER BY city_category DESC;

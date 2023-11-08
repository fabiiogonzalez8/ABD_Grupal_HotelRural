-- 1 . El cliente que ha realizado la estancia más larga de los últimos seis meses de entre
-- los que se encuentra actualmente en el hotel va a realizar la actividad de menor coste
-- en el día de hoy. La hará solo y la abonará sobre la marcha. Inserta el registro
-- oportuno.

-- 2. La actividad que han realizado más personas que se alojaban en regimen de todo
-- incluido en los últimos nueves meses sube su precio un 10%. Refleja el cambio en la base
-- de datos.

                -- Consulta para sacar el código:

                    SELECT SUM(numpersonas), codigoactividad
                    FROM actividadesrealizadas
                    WHERE codigoestancia IN (
                                                SELECT codigo
                                                FROM estancias
                                                WHERE fecha_fin >= (SELECT MAX(fecha_fin) FROM estancias ) - INTERVAL '9' MONTH
                                                AND codigoregimen IN (
                                                                        SELECT codigo
                                                                        FROM regimenes
                                                                        WHERE nombre = 'Todo Incluido')
                    )
                    GROUP BY codigoactividad;

                -- Actualizar el precio de la actividad:

                    UPDATE actividades
                    SET precioporpersona = precioporpersona * 1.10
                    WHERE codigo = 'A032'


-- 3. Muestra el número de estancias que no han realizado ningún tipo de actividad extra en
-- el último año agrupando por regimen de alojamiento.

SELECT r.nombre, COUNT(e.codigo) AS numero_estancias
FROM estancias e
JOIN regimenes r ON e.codigoregimen = r.codigo
LEFT JOIN actividadesrealizadas ar ON e.codigo = ar.codigoestancia 
    AND ar.fecha BETWEEN SYSDATE - INTERVAL '1' YEAR AND SYSDATE
WHERE ar.codigoestancia IS NULL
GROUP BY r.nombre;

-- 4. Muestra nombre y apellidos de los clientes que han realizado más de dos estancias de
-- más de una semana en una habitación de tipo suite.

SELECT p.nombre, p.apellidos
FROM personas p
WHERE (
    SELECT count(*)
    FROM estancias e
    WHERE e.nifcliente = p.nif
    AND e.fecha_fin - e.fecha_inicio >= 7
    AND numerohabitacion IN (
        SELECT numero from habitaciones WHERE
        codigotipo = '04'
    )
) >2 ;

-- 5. Muestra los nombres de los clientes que han venido al hotel tanto en primavera como
-- en verano como en otoño.

SELECT p.nombre, p.apellidos
FROM personas p
WHERE p.nif IN (
    SELECT e.nifcliente
    FROM estancias e
    WHERE e.fecha_inicio BETWEEN TO_DATE('21-03-2015', 'DD-MM-YYYY') AND TO_DATE('21-12-2015', 'DD-MM-YYYY')
);

-- 6. Muestra, para cada actividad con un coste para el hotel de más de diez euros, el
-- número de personas en regimen de todo incluido que las han realizado, incluyendo
-- aquéllas actividades que no hayan sido realizadas por ninguna.

-- 7. Muestra las habitaciones tipo suite que fueron ocupadas durante algún día de la
-- temporada baja.

SELECT count(*) as numeroestancias, numerohabitacion
FROM estancias e
WHERE e.fecha_inicio BETWEEN TO_DATE('01-11-2015', 'DD-MM-YYYY') AND TO_DATE('31-03-2016', 'DD-MM-YYYY')
AND e.numerohabitacion IN (
               				SELECT numero
                			FROM habitaciones h
							WHERE h.codigotipo IN (
													SELECT codigo
													FROM tipos_de_habitacion
													WHERE nombre = 'Suite')
)
GROUP BY e.numerohabitacion;

-- 8. Muestra el número de actividades realizadas en la estancia más reciente de cada uno
-- de los clientes.

select e.codigo as codigoestancia,
count (a.codigoactividad) as numero_actividades
from estancias e
left join actividadesrealizadas a on e.codigo = a.codigoestancia
where (e.codigo, e.fecha_inicio) in (
    select codigo, MAX(fecha_inicio)
    from estancias
    group by codigo
)
group by e.codigo
order by e.codigo;

-- 9. Muestra los nombres de las actividades que no han sido realizadas por ningún cliente
-- que no estuviera alojado en regimen de todo incluido en los últimos dos meses.

-- 10. Crea una vista con el nombre y apellidos del cliente, el nombre del regimen en que se
-- aloja y el tipo de habitación para aquellas estancias actuales que tienen pendiente de
-- pago alguna actividad realizada.

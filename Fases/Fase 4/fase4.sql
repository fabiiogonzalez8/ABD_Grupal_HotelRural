-- 1.Realiza una función ComprobarPago que reciba como parámetros un código de cliente y un código de actividad y
-- devuelva un TRUE si el cliente ha pagado la última actividad con ese códiggastos_extraso que ha realizado y un FALSE en caso
-- contrario. Debes controlar las siguientes excepciones: Cliente inexistente, Actividad Inexistente, Actividad realizada
-- en régimen de Todo Incluido y El cliente nunca ha realizado esa actividad.

## ORACLE

- Cliente inexistente.


create or replace procedure Clienteinexistente (p_clientenif personas.NIF%type)
IS 

    v_codcliente number;

begin

    select COUNT(*) INTO v_codcliente
    FROM personas
    where NIF = p_clientenif;
    if v_codcliente=0 then 
        RAISE_APPLICATION_ERROR(-20001, "ESTE CLIENTE NO EXISTE")
    end if;
end;
/


- Actividad Inexistente


create or replace procedure actividadinexistente (p_actividad actividades.codigoQ%type)
IS 

    v_codactividad number;

begin

    select COUNT(*) INTO v_codactividad
    FROM actividades
    where codigo = p_actividad;
    if v_codactividad=0 then 
        RAISE_APPLICATION_ERROR(-20002, "ESTA ACTIVIDAD NO EXISTE")
    end if;
end;
/


- Todo incluido

CREATE OR REPLACE PROCEDURE todoincluido (v_codActividad actividades.codigo%type)
IS
    v_todoincluido NUMBER;
BEGIN 
    SELECT COUNT(*)
    INTO v_todoincluido
    FROM actividadesrealizadas
    WHERE codigoestancia IN (SELECT MAX(codigo) FROM estancias WHERE codigoregimen = 'TI')
    AND codigoactividad = v_codActividad;

    IF v_todoincluido > 0 THEN 
        dbms_output.put_line('True');
    ELSE
        dbms_output.put_line('False');
    END IF;
END;
/



- El cliente nunca ha realizado esa actividad.

create or replace procedure noactividad (p_nif personas.NIF%type, p_codigo actividadesrealizadas.codigoactividad%type)
IS
    v_cliente number;
begin
    select COUNT(*) into v_cliente
    FROM estancias where NIFCliente = p_nif and 
    codigo in (select codigoestancia from actividadesrealizadas where codigoactividad=p_codigo);
    if v_cliente > 0 then
        dbms_output.put_line('Si ha realizado esta actividad');
    ELSE
        dbms_output.put_line('El cliente no ha realizado nunca esta actividad');
    END IF;
end; 
/


- Agrupal excepciones

CREATE OR REPLACE PROCEDURE Excepciones (p_clin personas.NIF%type,p_codac actividades.codigo%type)
IS
BEGIN
    Clienteinexistente(p_clin);
    actividadinexistente(p_codac);
    todoincluido(p_codac);
    noactividad(p_clin, p_codac);
END;
/


- Actividad abonada


CREATE OR REPLACE PROCEDURE A_Abonada (p_codcl personas.nif%type,
p_codacti actividades.codigo%type)
IS
    CURSOR c_abonada IS
    SELECT *
    FROM actividadesrealizadas
    WHERE codigoestancia = (SELECT codigo FROM estancias WHERE
    nifcliente=p_codcl) AND codigoactividad=p_codacti
    ORDER BY fecha DESC
    FETCH FIRST 1 ROWS ONLY;
    v_actabo actividadesrealizadas%ROWTYPE;
BEGIN
    OPEN c_abonada;
    FETCH c_abonada INTO v_actabo;
    IF v_actabo.abonado = 'N' THEN

    DBMS_OUTPUT.PUT_LINE('FALSE');
    ELSE
    DBMS_OUTPUT.PUT_LINE('TRUE');
    END IF;

    CLOSE c_abonada;

END;
/


- Función.

CREATE OR REPLACE FUNCTION comprobarPago (p_codcliente personas.NIF%type, p_codactividad
actividades.codigo%type)
RETURN BOOLEAN
IS
    v_cliente BOOLEAN;
BEGIN
    Excepciones(v_codcliente, v_codactividad);
    A_Abonada(v_codcliente, v_codactividad);
    RETURN v_cliente;
END;
/



-- 2.Realiza un procedimiento llamado ImprimirFactura que reciba un código de estancia e imprima la factura vinculada
-- a la misma. Debes tener en cuenta que la factura tendrá el siguiente formato:

-- Complejo Rural La Fuente
-- Candelario (Salamanca)
-- Código Estancia: xxxxxxxx
-- Cliente: NombreCliente ApellidosCliente
-- Número Habitación: nnn
-- Fecha Inicio: nn/nn/n.nnn
-- Fecha Salida: nn/nn/nnnn
-- Régimen de Alojamiento: NombreRegimen

-- Alojamiento
-- Temporada1
-- NumDías1Importe1
-- NumDíasNImporteN

-- …

-- TemporadaN
-- Importe Total Alojamiento: n.nnn,nn
-- Gastos Extra

-- Fecha1
-- Concepto1Cuantía1
-- ConceptoNCuantíaN
-- ….

-- FechaN
-- Importe Total Gastos Extra: n.nnn,nn
-- Actividades Realizadas

-- Fecha1
-- NombreActividad1NumPersonas1Importe1
-- NombreActividadNNumPersonasNImporteN

-- …

-- FechaN
-- Importe Total Actividades Realizadas: n.nnn
-- Importe Factura: nn.nnn,nn

-- Notas: Si la estancia se ha hecho en régimen de Todo Incluido no se imprimirán los apartados de Gastos Extra o
-- Actividades Realizadas. Del mismo modo, si en la estancia no se ha efectuado ninguna Actividad o Gasto Extra, no
-- aparecerán en la factura.
-- Si una Actividad ha sido abonada in situ tampoco aparecerá en la factura.
-- Debes tener cuidado de facturar bien las estancias que abarcan varias temporadas.


        -- Función para devolver el nombre del cliente por el código de la estancia
        CREATE OR REPLACE FUNCTION f_devolver_nombrecliente (p_CodEst estancias.codigo%TYPE)
        RETURN VARCHAR2
        IS 
            v_nombre VARCHAR2(100);
        BEGIN
            SELECT nombre || ' ' || apellidos INTO v_nombre
            FROM personas
            WHERE nif = (SELECT nifcliente
                         FROM estancias
                         WHERE codigo = p_CodEst);

            RETURN v_nombre;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN 
                RETURN 'No se ha encontrado cliente';
            WHEN TOO_MANY_ROWS THEN
                RETURN 'error, hay más de un cliente registrado con ese código';
        END;
        /

        -- Procedimiento para mostrar la habitación con las fechas de la estancia.
            CREATE OR REPLACE PROCEDURE p_mostrar_estancia (p_CodEst estancias.codigo%TYPE)
            AS
                CURSOR c_alojamiento IS
                SELECT numerohabitacion, fecha_inicio, fecha_fin
                FROM estancias
                WHERE codigo = p_CodEst;
            BEGIN
                FOR c_registro IN c_alojamiento LOOP
                DBMS_OUTPUT.PUT_LINE('Número Habitación: '||c_registro.numerohabitacion||' Fecha Inicio: '||c_registro.fecha_inicio||' Fecha Fin: '||c_registro.fecha_fin);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN 
                    DBMS_OUTPUT.PUT_LINE('No se ha encontrado estancia');
                WHEN TOO_MANY_ROWS THEN
                    DBMS_OUTPUT.PUT_LINE('Se ha encontrado más de una estancia con ese código');
            END;
            /
    
        -- Procedimiento para mostrar la estancia, cliente y el tipo de régimen.
            CREATE OR REPLACE PROCEDURE p_mostrar_regimen (p_CodEst estancias.codigo%TYPE)
            AS 
                CURSOR c_regimen IS
                SELECT nombre
                FROM regimenes
                WHERE codigo = (SELECT codigoregimen
                                FROM estancias
                                WHERE codigo = p_CodEst);
            BEGIN
                FOR c_registro IN c_regimen LOOP
                    DBMS_OUTPUT.PUT_LINE('Codigo Estancia: '||p_CodEst);
                    DBMS_OUTPUT.PUT_LINE('Cliente: '||f_devolver_nombrecliente(p_CodEst));
                    p_mostrar_estancia(p_CodEst);
                    DBMS_OUTPUT.PUT_LINE('Regimen de Alojamiento: '||c_registro.nombre);
                END LOOP;
            END;
            /

        -- Función para devolver el importe total
            CREATE OR REPLACE FUNCTION f_devolver_ImporteAlojamiento (p_CodEst estancias.codigo%TYPE)
            RETURN NUMBER
            IS
                v_importe NUMBER;
            BEGIN
                SELECT SUM(preciopordia) INTO v_importe
                FROM tarifas
                WHERE codigoregimen = (SELECT codigoregimen
                                       FROM estancias
                                       WHERE codigo = p_CodEst);
                RETURN v_importe;
            END;
            /

        -- Procedimiento para que muestre el importe total por el código de estancia
            CREATE OR REPLACE PROCEDURE p_motrar_importealojamiento (p_CodEst estancias.codigo%TYPE)
            AS
                CURSOR c_alojamiento IS
                    SELECT te.nombre, te.fecha_fin - te.fecha_inicio AS dias, ta.preciopordia
                    FROM temporadas te
                    JOIN tarifas ta ON te.codigo = ta.codigotemporada
                    WHERE ta.codigoregimen = (SELECT codigoregimen, 
                                              FROM estancias
                                              WHERE codigo = p_CodEst)
                    ORDER BY te.nombre;

            BEGIN
                DBMS_OUTPUT.PUT_LINE('Alojamiento');
                DBMS_OUTPUT.PUT_LINE('-----------');

                FOR c_registro IN c_alojamiento LOOP
                    DBMS_OUTPUT.PUT_LINE(c_registro.nombre||chr(9)||c_registro.dias||chr(9)||c_registro.preciopordia);
                END LOOP;

                DBMS_OUTPUT.PUT_LINE('Importe Total Alojamiento: ' || f_devolver_ImporteAlojamiento(p_CodEst));
            EXCEPTION
                WHEN NO_DATA_FOUND THEN 
                    DBMS_OUTPUT.PUT_LINE('No se ha encontrado alojamiento');
            END;
            /

        
        -- Función para devolver los gastos extras
            CREATE OR REPLACE FUNCTION f_devolver_importeGastosExtras (p_CodEst estancias.codigo%TYPE)
            RETURN NUMBER
            IS
            	v_gastos NUMBER;
            BEGIN
                SELECT SUM(cuantia) INTO v_gastos
                FROM gastos_extra
                WHERE codigoestancia = (SELECT codigo
                                        FROM estancias
                                        WHERE codigo = p_CodEst);
                RETURN v_gastos;
            END;
            /
        
        -- Función para comprobar regimen de Todo Incluido
            CREATE OR REPLACE FUNCTION f_comprobar_TodoIncluido (p_CodEst estancias.codigo%TYPE)
            RETURN VARCHAR2
            IS
                v_codigo regimenes.codigo%TYPE;
            BEGIN
                SELECT codigo INTO v_codigo
                FROM regimenes
                WHERE codigo = (SELECT codigoregimen
                                FROM estancias
                                WHERE codigo = p_CodEst);

                RETURN v_codigo;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RETURN 'Estancia no encontrada';
            END;
            /

        -- Procedimiento para mostrar los gastos extras por el cliente
            CREATE OR REPLACE PROCEDURE p_mostrar_GastosExtras (p_CodEst estancias.codigo%TYPE)
		    AS
                CURSOR c_gastoextra IS
                    SELECT concepto, fecha, cuantia
                    FROM gastos_extra
                    WHERE codigoestancia = (SELECT codigo
                                            FROM estancias
                                            WHERE codigo = p_CodEst);
            BEGIN
                IF f_comprobar_TodoIncluido(p_CodEst) != 'TI' THEN
                    FOR c_registro IN c_gastoextra LOOP
                        DBMS_OUTPUT.PUT_LINE('Gastos extras');
                        DBMS_OUTPUT.PUT_LINE('-------------');
                        DBMS_OUTPUT.PUT_LINE(c_registro.concepto||chr(7)||c_registro.fecha||chr(7)||c_registro.cuantia);
                    END LOOP;
                    DBMS_OUTPUT.PUT_LINE('Importe Total Gastos Extras: '||f_devolver_importeGastosExtras(p_CodEst));
                ELSIF f_comprobar_TodoIncluido(p_CodEst) = 'TI' THEN
                    DBMS_OUTPUT.PUT_LINE('');
                END IF;
            END;
            /

        -- Función para devolver el importe de las actividades realizadas por persona y numero de personas
            CREATE OR REPLACE FUNCTION f_devolver_importeactividades (p_CodEst estancias.codigo%TYPE)
            RETURN NUMBER
            IS
                v_actividades NUMBER;
            BEGIN
                SELECT SUM(precioporpersona * numpersonas) INTO v_actividades
                FROM actividadesrealizadas, actividades
                WHERE codigo = codigoactividad AND codigoestancia = (SELECT codigo
                                                                     FROM estancias
                                                                     WHERE codigo = p_CodEst);
                RETURN v_actividades;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    RETURN 'Actividad no encontrada';
            END;
            /

        -- Procedimiento para mostrar las actividades realizadas
            CREATE OR REPLACE PROCEDURE p_mostrar_ActividadRealizada (p_CodEst estancias.codigo%TYPE)
		    AS 
                CURSOR c_actividadReal IS
                SELECT fecha, nombre, numpersonas, (precioporpersona * numpersonas) AS total
                FROM actividadesrealizadas, actividades
                WHERE codigo = codigoactividad AND codigoestancia = (SELECT codigo
                                                                    FROM estancias
                                                                    WHERE codigo = p_CodEst);
		    BEGIN
                IF f_comprobar_TodoIncluido(p_CodEst) != 'TI' THEN
                    FOR c_registro IN c_actividadReal LOOP
                        IF TO_DATE(SYSDATE, 'DD-MM-YYYY hh24:mi') != c.fecha THEN
                            DBMS_OUTPUT.PUT_LINE('Actividades realizadas');
                            DBMS_OUTPUT.PUT_LINE('---------------------');
                            DBMS_OUTPUT.PUT_LINE(c_registro.fecha||chr(9)||c_registro.nombre||chr(9)||c_registro.numpersonas||chr(9)||c_registro.total);
                        END IF;
                    END LOOP;
                    DBMS_OUTPUT.PUT_LINE('Importe Total Actividades Realizadas: '||f_devolver_importeactividades(p_CodEst));
                ELSIF f_comprobar_TodoIncluido(p_CodEst) = 'TI' THEN
                    DBMS_OUTPUT.PUT_LINE('');
                END IF;
            END;
            /

        
        -- Procedimiento para calcular la factura
            CREATE OR REPLACE PROCEDURE p_calcular_factura (p_CodEst estancias.codigo%TYPE)
            AS
                v_alojamiento NUMBER;
                v_gastosextras NUMBER;
                v_actividadesReal NUMBER;
                v_TotalGastos NUMBER;
            BEGIN
                v_alojamiento := f_devolver_ImporteAlojamiento(p_CodEst);
                v_gastosextras := f_devolver_importeGastosExtras(p_CodEst);
                v_actividadesReal := f_devolver_importeactividades(p_CodEst);
                v_TotalGastos := v_alojamiento + v_gastosextras + v_actividadesReal;
                DBMS_OUTPUT.PUT_LINE('Importe Factura: '||v_TotalGastos);
            END;
            /
        
        -- Procedimiento para mostrar la factura del cliente 
            CREATE OR REPLACE PROCEDURE MostrarFactura (p_CodEst estancias.codigo%TYPE)
            AS
            BEGIN
                DBMS_OUTPUT.PUT_LINE('Complejo Rural La Fuente');
                DBMS_OUTPUT.PUT_LINE('Candelario (Salamanca)');
                DBMS_OUTPUT.PUT_LINE(chr(5));
                p_mostrar_regimen(p_CodEst);
                DBMS_OUTPUT.PUT_LINE(chr(5));
                p_mostrar_estancia(p_CodEst);
                DBMS_OUTPUT.PUT_LINE(chr(5));
                p_mostrar_GastosExtras(p_CodEst);
                DBMS_OUTPUT.PUT_LINE(chr(5));
                p_mostrar_ActividadRealizada(p_CodEst);
                DBMS_OUTPUT.PUT_LINE(chr(5));
                p_calcular_factura(p_CodEst);
            END;
            /

    exec MostrarFactura('04');

--3.Realiza un trigger que impida que haga que cuando se inserte la realización de una actividad asociada a una
-- estancia en regimen TI el campo Abonado no pueda valer FALSE.

    CREATE OR REPLACE TRIGGER ActividadenTI
    AFTER INSERT ON actividadrealizada
    fOR EACH ROW
    DECLARE
        v_estancia VARCHAR2(2);
    BEGIN
        SELECT codigo INTO v_estancia
        FROM regimenes
        WHERE codigo IN (SELECT codigoregimen
                         FROM estancias
                         WHERE codigo = :new.codigoestancia);

        IF v_estancia = 'TI' AND :new.abonado = 'N' THEN
            RAISE_APPLICATION_ERROR(-20100, 'La actividad en regimen Todo Incluido debe estar abonada.')
        END IF;  
    END;
    /
    -- comprobar trigger --
    INSERT INTO actividadrealizada VALUES ('04','B302',TO_DATE('10-08-2022 12:00','DD-MM-YYYY hh24:mi'),4,'N');



-- 4.Añade un campo email a los clientes y rellénalo para algunos de ellos. Realiza un trigger que cuando se rellene el
-- campo Fecha de la Factura envíe por correo electrónico un resumen de la factura al cliente, incluyendo los datos
-- fundamentales de la estancia, el importe de cada apartado y el importe total.

        -- Añadir columna email a la tabla personas
            ALTER TABLE personas ADD email VARCHAR2(50);

        -- Datos

            UPDATE personas
            SET email = 
                CASE 
                    WHEN nif = '36059752F' THEN 'antonio.melandez@gmail.com'
                    WHEN nif = '10402498N' THEN 'carlosm@outlook.com'
                    WHEN nif = '10950967T' THEN 'ana17gutierrez@gmail.com'
                    WHEN nif = '54890865P' THEN 'a.rodriguez@gmail.com'
                    WHEN nif = '40687067K' THEN 'aitor-leon22@gmail.com'
                    WHEN nif = '77399071T' THEN 'virginia.leon@outlook.com'
                    WHEN nif = '69191424H' THEN 'antonio.fernandez@gmail.com'
                    WHEN nif = '88095695Z' THEN 'shu_adrian_garcia@hotmail.com'
                    WHEN nif = '95327640T' THEN 'juan.romero@gmail.com'
                    WHEN nif = '06852683V' THEN 'tito_franco23@hotmail.com'
                    ELSE email
                END;
        -- 

-- 5.Añade a la tabla Actividades una columna llamada BalanceHotel. La columna contendrá la cantidad que debe
-- pagar el hotel a la empresa (en cuyo caso tendrá signo positivo) o la empresa al hotel (en cuyo caso tendrá signo
-- negativo) a causa de las Actividades Realizadas por los clientes. Realiza un procedimiento que rellene dicha
-- columna y un trigger que la mantenga actualizada cada vez que la tabla ActividadesRealizadas sufra cualquier
-- cambio.
-- Te recuerdo que cada vez que un cliente realiza una actividad, hay dos posibilidades: Si el cliente está en TI el
-- hotel paga a la empresa el coste de la actividad. Si no está en TI, el hotel recibe un porcentaje de comisión del
-- importe que paga el cliente por realizar la actividad.

-- Creo la columna

alter table actividades add (BalanceHotel number(10,2));

-- Procedimiento para actualizar los datos de la columna nueva

create or replace procedure actualizar_balance_hotel(p_codigo_actividad varchar2)
is
  v_balance number(10,2) := 0;
begin
  select sum(
           case
             when p.codigoregimen = 'TI' then a.costepersonaparahotel * ar.numpersonas
             else -1 * a.comisionhotel * ar.numpersonas
           end
         ) into v_balance
    from actividades a
         join actividadesrealizadas ar on a.codigo = ar.codigoactividad
         join estancias e on ar.codigoestancia = e.codigo
         join regimenes p on e.codigoregimen = p.codigo
   where a.codigo = p_codigo_actividad;
  
  update actividades
     set balancehotel = nvl(v_balance, 0)
   where codigo = p_codigo_actividad;
end actualizar_balance_hotel;
/


-- Crear trigger para actualizar BalanceHotel después de un cambio en actividadesrealizadas

create or replace trigger trg_actualizar_balance_hotel
after insert or update or delete on actividadesrealizadas
for each row
begin
  actualizar_balance_hotel(:new.codigoactividad);
end;
/

-- 6.Realiza los módulos de programación necesarios para que una actividad no sea realizada en una fecha concreta
-- por más de 10 personas.

-- necesito actividad, fecha y num personas

-- Creo el paquete con el tipo de datos registro. Aqui pongo
-- los datos que voy a necesitar de la tabla.

create or replace package paquete_10personas
as
type tactividad is record
(
    codigoactividad actividadesrealizadas.codigoactividad%type,
    fecha actividadesrealizadas.fecha%type,
    numeropersonas number
);

-- Defino el tipo de datos tabla 

type ttablaactividad is table of tactividad
index by binary_integer;

-- Declaro una variable del tipo tabla antes creado

v_tablaactividad ttablaactividad;
end paquete_10personas;
/

-- Empiezo a rellenar la tabla ttablactividad

create or replace trigger rellenarvariablestabla
before insert or update on actividadesrealizadas
declare
    cursor cur_actividad
    is
    select codigoactividad, fecha, sum(numpersonas) as numpersonas
    from actividades a, actividadesrealizadas ar
    where a.codigo = ar.codigoactividad
    group by codigoactividad, fecha
    order by fecha;
    indice NUMBER := 0;
begin
    for i in cur_actividad loop
        paquete_10personas.v_tablaactividad(indice).codigoactividad := i.codigoactividad;
        paquete_10personas.v_tablaactividad(indice).fecha := i.fecha;
        paquete_10personas.v_tablaactividad(indice).numeropersonas := i.numpersonas;
        indice := indice + 1;
    end loop;
end rellenarvariablestabla;
/

-- Hago la comprobación de que no haya mas de 10 personas en una actividad para una fecha concreta.

create or replace trigger nomasde10
before insert or update on actividadesrealizadas
for each row 
declare
begin
    for i in paquete_10personas.v_tablaactividad.first..paquete_10personas.v_tablaactividad.last loop
        if paquete_10personas.v_tablaactividad(i).fecha = :new.fecha and paquete_10personas.v_tablaactividad(i).numeropersonas < 10 and paquete_10personas.v_tablaactividad(i).codigoactividad = :new.codigoactividad then
            raise_application_error(-20020, 'No pueden participar mas de 10 personas en esta actividad para esta fecha');
        end if;
    end loop;
    paquete_10personas.v_tablaactividad(paquete_10personas.v_tablaactividad.LAST+1).codigoactividad := :new.codigoactividad;
    paquete_10personas.v_tablaactividad(paquete_10personas.v_tablaactividad.LAST).fecha := :new.fecha;
    paquete_10personas.v_tablaactividad(paquete_10personas.v_tablaactividad.LAST).numeropersonas := :new.numpersonas;
end nomasde10;
/

-- Para comprobar el funcionamiento creo una tabla llamada actividadesrealizadas2 en la que inserto algunos datos.
-- Estas filas insertadas las añado a la tabla actividadesrealizadas a partir de esta nueva tabla


-- 7.Realiza los módulos de programación necesarios para que los precios de un mismo tipo de habitación en una
-- misma temporada crezca en función de los servicios ofrecidos de esta forma: Precio TI > Precio PC > Precio MP>
-- Precio AD

-- 8.Realiza los módulos de programación necesarios para que un cliente no pueda realizar dos estancias que se
-- solapen en fechas entre ellas, esto es, un cliente no puede comenzar una estancia hasta que no haya terminado la
-- anterior.

-- Creacion del paquete para controlar las fechas.

CREATE OR REPLACE PACKAGE Solapada AS

  TYPE registro_fechas_typ IS RECORD (
    cliente_nif estancias.nifcliente%TYPE,
    inicio_fecha estancias.fecha_inicio%TYPE,
    fin_fecha estancias.fecha_fin%TYPE
  );

  TYPE tabla_fechas_typ IS TABLE OF registro_fechas_typ INDEX BY BINARY_INTEGER;
  fechas tabla_fechas_typ;
END Solapada;
/

-----------------------------------------------------------------------------------------
-- Rellenar tabla.

CREATE OR REPLACE TRIGGER rellenarfechas
BEFORE INSERT OR UPDATE ON estancias
DECLARE
  CURSOR cursor_fechas IS SELECT nifcliente, fecha_inicio, fecha_fin FROM estancias;
  ind NUMBER := 0;
BEGIN
  FOR i IN cursor_fechas LOOP
    Solapada.fechas(ind).cliente_nif := i.nifcliente;
    Solapada.fechas(ind).inicio_fecha := i.fecha_inicio;
    Solapada.fechas(ind).fin_fecha := i.fecha_fin;
    indice := indice + 1;
  END LOOP;
END rellenarfechas;
/

--------------------------------------------------------------------------------------------------
-- Comprobar fecha


CREATE OR REPLACE TRIGGER comprobarfecha
BEFORE INSERT OR UPDATE ON estancias
FOR EACH ROW
DECLARE
BEGIN
  FOR i IN Solapada.fechas.FIRST..Solapada.fechas.LAST LOOP
    IF Solapada.fechas(i).cliente_nif = :NEW.nifcliente THEN
      IF :NEW.fecha_inicio BETWEEN Solapada.fechas(i).inicio_fecha AND Solapada.fechas(i).fin_fecha THEN
        RAISE_APPLICATION_ERROR(-20000, 'No se puede mas de dos en el mismo dia');
      END IF;
      
      IF :NEW.fecha_fin BETWEEN Solapada.fechas(i).inicio_fecha AND Solapada.fechas(i).fin_fecha THEN
        RAISE_APPLICATION_ERROR(-20001, 'No se puede mas de dos en el mismo dia');
      END IF;
    END IF;
  END LOOP;
END comprobarfecha;
/




------------------------------------------- EJERCICIOS EN POSTGRESQL -------------------------------------------------


-- Realiza un trigger que impida que haga que cuando se inserte la realización de una actividad asociada a una
-- estancia en regimen TI el campo Abonado no pueda valer FALSE.

CREATE OR REPLACE FUNCTION estanciaTI() 
RETURNS TRIGGER AS $$
DECLARE
    v_estancia
BEGIN
    SELECT codigo INTO v_estancia
    FROM regimenes
    WHERE codigo IN (SELECT codigoregimen
                     FROM estancias
                     WHERE codigo = NEW.codigoestancia);

    IF v_codigo = 'TI' AND NEW.abonado = 'N' THEN
        RAISE NOTICE '%', 'La actividad en regimen Todo Incluido debe estar abonada';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER estanciaTI
AFTER INSERT ON actividadrealizada
FOR EACH ROW 
EXECUTE FUNCTION estanciaTI();

-- Comprobar trigger ---

    INSERT INTO actividadrealizada VALUES ('04','B302',TO_DATE('10-08-2022 12:00','DD-MM-YYYY hh24:mi'),4,'N');


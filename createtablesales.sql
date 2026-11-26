CREATE TABLE dim.tienda (
    tienda_id       INT IDENTITY(1,1) NOT NULL,
    codigo_tienda   VARCHAR(10)       NOT NULL,
    nombre_tienda   VARCHAR(80)       NOT NULL,
    region          VARCHAR(40)       NOT NULL,
    ciudad          VARCHAR(60)       NOT NULL,
    formato         VARCHAR(30)       NOT NULL,
    fecha_apertura  DATE              NOT NULL,
    activa          BIT               NOT NULL CONSTRAINT DF_tienda_activa DEFAULT 1,

    CONSTRAINT PK_tienda        PRIMARY KEY (tienda_id),
    CONSTRAINT UQ_tienda_codigo UNIQUE (codigo_tienda)
);

CREATE TABLE dim.vendedor (
    vendedor_id      INT IDENTITY(1,1) NOT NULL,
    codigo_vendedor  VARCHAR(10)       NOT NULL,
    nombre_completo  VARCHAR(100)      NOT NULL,
    tienda_id        INT               NOT NULL,
    cargo            VARCHAR(30)       NOT NULL,
    fecha_ingreso    DATE              NOT NULL,
    activo           BIT               NOT NULL CONSTRAINT DF_vendedor_activo DEFAULT 1,

    CONSTRAINT PK_vendedor        PRIMARY KEY (vendedor_id),
    CONSTRAINT UQ_vendedor_codigo UNIQUE (codigo_vendedor),
    CONSTRAINT FK_vendedor_tienda FOREIGN KEY (tienda_id)
        REFERENCES dim.tienda (tienda_id)
);

CREATE TABLE dim.producto (
    producto_id       INT IDENTITY(1,1) NOT NULL,
    codigo_producto   VARCHAR(10)       NOT NULL,
    nombre_producto   VARCHAR(80)       NOT NULL,
    categoria         VARCHAR(40)       NOT NULL,
    precio_referencia DECIMAL(10,2)     NOT NULL,

    CONSTRAINT PK_producto        PRIMARY KEY (producto_id),
    CONSTRAINT UQ_producto_codigo UNIQUE (codigo_producto),
    CONSTRAINT CK_producto_precio CHECK (precio_referencia >= 0)
);

CREATE TABLE dim.calendario (
    fecha            DATE        NOT NULL,
    anio             SMALLINT    NOT NULL,
    mes              TINYINT     NOT NULL,
    nombre_mes       VARCHAR(15) NOT NULL,
    anio_mes         CHAR(7)     NOT NULL,   -- formato 'YYYY-MM'
    inicio_mes       DATE        NOT NULL,
    semana_iso       TINYINT     NOT NULL,
    dia_semana       TINYINT     NOT NULL,   -- 1 = lunes ... 7 = domingo
    nombre_dia       VARCHAR(15) NOT NULL,
    es_fin_de_semana BIT         NOT NULL,

    CONSTRAINT PK_calendario PRIMARY KEY (fecha),
    CONSTRAINT CK_calendario_mes CHECK (mes BETWEEN 1 AND 12),
    CONSTRAINT CK_calendario_dia CHECK (dia_semana BETWEEN 1 AND 7)
);


SELECT s.name AS esquema, t.name AS tabla
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('dim', 'fact')
ORDER BY s.name, t.name;


CREATE TABLE fact.ventas (
    venta_id      BIGINT IDENTITY(1,1) NOT NULL,
    operacion_id  VARCHAR(20)          NOT NULL,
    fecha         DATE                 NOT NULL,
    tienda_id     INT                  NOT NULL,
    vendedor_id   INT                  NOT NULL,
    producto_id   INT                  NOT NULL,
    cantidad      INT                  NOT NULL,
    monto         DECIMAL(12,2)        NOT NULL,

    CONSTRAINT PK_ventas          PRIMARY KEY (venta_id),
    CONSTRAINT UQ_ventas_grano    UNIQUE (operacion_id, producto_id),
    CONSTRAINT FK_ventas_calendario FOREIGN KEY (fecha)       REFERENCES dim.calendario (fecha),
    CONSTRAINT FK_ventas_tienda     FOREIGN KEY (tienda_id)   REFERENCES dim.tienda (tienda_id),
    CONSTRAINT FK_ventas_vendedor   FOREIGN KEY (vendedor_id) REFERENCES dim.vendedor (vendedor_id),
    CONSTRAINT FK_ventas_producto   FOREIGN KEY (producto_id) REFERENCES dim.producto (producto_id),
    CONSTRAINT CK_ventas_cantidad   CHECK (cantidad > 0),
    CONSTRAINT CK_ventas_monto      CHECK (monto >= 0)
);



CREATE NONCLUSTERED INDEX IX_ventas_fecha    ON fact.ventas (fecha);
CREATE NONCLUSTERED INDEX IX_ventas_tienda   ON fact.ventas (tienda_id);
CREATE NONCLUSTERED INDEX IX_ventas_vendedor ON fact.ventas (vendedor_id);



CREATE TABLE fact.meta_vendedor (
    vendedor_id    INT           NOT NULL,
    inicio_mes     DATE          NOT NULL,
    meta_monto     DECIMAL(12,2) NOT NULL,
    meta_unidades  INT           NOT NULL,

    CONSTRAINT PK_meta_vendedor PRIMARY KEY (vendedor_id, inicio_mes),
    CONSTRAINT FK_meta_vendedor_vendedor   FOREIGN KEY (vendedor_id) REFERENCES dim.vendedor (vendedor_id),
    CONSTRAINT FK_meta_vendedor_calendario FOREIGN KEY (inicio_mes)  REFERENCES dim.calendario (fecha),
    CONSTRAINT CK_meta_vendedor_dia1   CHECK (DAY(inicio_mes) = 1),
    CONSTRAINT CK_meta_vendedor_monto  CHECK (meta_monto >= 0),
    CONSTRAINT CK_meta_vendedor_unid   CHECK (meta_unidades >= 0)
);


CREATE TABLE fact.meta_tienda (
    tienda_id      INT           NOT NULL,
    inicio_mes     DATE          NOT NULL,
    meta_monto     DECIMAL(12,2) NOT NULL,
    meta_unidades  INT           NOT NULL,

    CONSTRAINT PK_meta_tienda PRIMARY KEY (tienda_id, inicio_mes),
    CONSTRAINT FK_meta_tienda_tienda     FOREIGN KEY (tienda_id)  REFERENCES dim.tienda (tienda_id),
    CONSTRAINT FK_meta_tienda_calendario FOREIGN KEY (inicio_mes) REFERENCES dim.calendario (fecha),
    CONSTRAINT CK_meta_tienda_dia1   CHECK (DAY(inicio_mes) = 1),
    CONSTRAINT CK_meta_tienda_monto  CHECK (meta_monto >= 0),
    CONSTRAINT CK_meta_tienda_unid   CHECK (meta_unidades >= 0)
);

SELECT s.name AS esquema, t.name AS tabla
FROM sys.tables t
JOIN sys.schemas s ON s.schema_id = t.schema_id
WHERE s.name IN ('dim', 'fact')
ORDER BY s.name, t.name;


SELECT
    OBJECT_SCHEMA_NAME(fk.parent_object_id) + '.' + OBJECT_NAME(fk.parent_object_id)         AS tabla_hija,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) + '.' + OBJECT_NAME(fk.referenced_object_id) AS tabla_padre,
    fk.name AS llave_foranea
FROM sys.foreign_keys fk
ORDER BY tabla_hija, tabla_padre;

USE TEX_Sales_Intelligence;
GO







WITH fechas AS (
    SELECT CAST('2026-08-01' AS DATE) AS fecha
    UNION ALL
    SELECT DATEADD(DAY, 1, fecha) FROM fechas WHERE fecha < '2026-10-31'
),
base AS (
    SELECT
        fecha,
        (DATEDIFF(DAY, '19000101', fecha) % 7) + 1 AS dia_iso   -- 1 = lunes ... 7 = domingo
    FROM fechas
)
INSERT INTO dim.calendario
    (fecha, anio, mes, nombre_mes, anio_mes, inicio_mes,
     semana_iso, dia_semana, nombre_dia, es_fin_de_semana)
SELECT
    fecha,
    YEAR(fecha),
    MONTH(fecha),
    CHOOSE(MONTH(fecha), 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
                         'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'),
    CONVERT(CHAR(7), fecha, 23),
    DATEFROMPARTS(YEAR(fecha), MONTH(fecha), 1),
    DATEPART(ISO_WEEK, fecha),
    dia_iso,
    CHOOSE(dia_iso, 'Lunes','Martes','Miércoles','Jueves','Viernes','Sábado','Domingo'),
    CASE WHEN dia_iso IN (6, 7) THEN 1 ELSE 0 END
FROM base
OPTION (MAXRECURSION 0);


INSERT INTO dim.tienda
    (codigo_tienda, nombre_tienda, region, ciudad, formato, fecha_apertura)
VALUES
('T-001', 'TEX Piura Centro',     'Piura',       'Piura',      'Tienda calle', '2018-03-12'),
('T-002', 'TEX Piura Mall Norte', 'Piura',       'Piura',      'Mall',         '2019-09-20'),
('T-003', 'TEX Piura Sur',        'Piura',       'Piura',      'Isla',         '2021-04-15'),
('T-004', 'TEX Castilla',         'Piura',       'Castilla',   'Tienda calle', '2020-02-01'),
('T-005', 'TEX Sullana Centro',   'Piura',       'Sullana',    'Tienda calle', '2017-11-05'),
('T-006', 'TEX Sullana Mall',     'Piura',       'Sullana',    'Mall',         '2022-06-18'),
('T-007', 'TEX Paita',            'Piura',       'Paita',      'Isla',         '2021-12-03'),
('T-008', 'TEX Talara',           'Piura',       'Talara',     'Tienda calle', '2019-05-27'),
('T-009', 'TEX Chulucanas',       'Piura',       'Chulucanas', 'Isla',         '2023-01-14'),
('T-010', 'TEX Tumbes Centro',    'Tumbes',      'Tumbes',     'Tienda calle', '2018-08-09'),
('T-011', 'TEX Tumbes Mall',      'Tumbes',      'Tumbes',     'Mall',         '2022-10-22'),
('T-012', 'TEX Chiclayo Centro',  'Lambayeque',  'Chiclayo',   'Tienda calle', '2016-07-30'),
('T-013', 'TEX Chiclayo Mall',    'Lambayeque',  'Chiclayo',   'Mall',         '2020-11-11'),
('T-014', 'TEX Trujillo Centro',  'La Libertad', 'Trujillo',   'Tienda calle', '2019-03-08'),
('T-015', 'TEX Trujillo Mall',    'La Libertad', 'Trujillo',   'Mall',         '2023-08-25');



INSERT INTO dim.producto
    (codigo_producto, nombre_producto, categoria, precio_referencia)
VALUES
('P-01', 'Chip prepago',                  'Prepago',        10.00),
('P-02', 'Línea postpago nueva',          'Postpago',       59.00),
('P-03', 'Portabilidad postpago',         'Portabilidad',   49.00),
('P-04', 'Smartphone gama de entrada',    'Equipos',       399.00),
('P-05', 'Smartphone gama media',         'Equipos',       899.00),
('P-06', 'Smartphone gama alta',          'Equipos',      2499.00),
('P-07', 'Router 4G',                     'Internet hogar', 199.00),
('P-08', 'Plan internet hogar fibra',     'Internet hogar',  79.00),
('P-09', 'Accesorios',                    'Accesorios',      35.00),
('P-10', 'Protección de equipo',          'Servicios',       25.00);




-- 1) Calendario: esperamos 92 días, del 2026-08-01 al 2026-10-31
SELECT COUNT(*) AS dias, MIN(fecha) AS desde, MAX(fecha) AS hasta
FROM dim.calendario;

-- 2) Días por mes: esperamos 31, 30 y 31
SELECT anio_mes, COUNT(*) AS dias
FROM dim.calendario
GROUP BY anio_mes
ORDER BY anio_mes;

-- 3) Días de fin de semana: esperamos 27
SELECT SUM(CAST(es_fin_de_semana AS INT)) AS dias_fin_de_semana
FROM dim.calendario;

-- 4) Tiendas por región: esperamos Piura 9, Tumbes 2, Lambayeque 2, La Libertad 2
SELECT region, COUNT(*) AS tiendas
FROM dim.tienda
GROUP BY region
ORDER BY tiendas DESC;

-- 5) Productos: esperamos 10 filas
SELECT COUNT(*) AS productos FROM dim.producto;

select * from dim.tienda;


USE TEX_Sales_Intelligence;
GO

CREATE SCHEMA stg;
GO

CREATE TABLE stg.vendedor_semilla (
    codigo_vendedor      VARCHAR(10)  NOT NULL,
    nombre_completo      VARCHAR(100) NOT NULL,
    codigo_tienda        VARCHAR(10)  NOT NULL,
    cargo                VARCHAR(30)  NOT NULL,
    perfil               VARCHAR(20)  NOT NULL,
    factor_productividad DECIMAL(4,2) NOT NULL,
    ingreso_fijo         DATE         NULL,
    activo               BIT NOT NULL CONSTRAINT DF_semilla_activo DEFAULT 1,
    activo_ago           BIT NOT NULL CONSTRAINT DF_semilla_ago    DEFAULT 1,
    activo_sep           BIT NOT NULL CONSTRAINT DF_semilla_sep    DEFAULT 1,
    activo_oct           BIT NOT NULL CONSTRAINT DF_semilla_oct    DEFAULT 1,

    CONSTRAINT PK_vendedor_semilla PRIMARY KEY (codigo_vendedor),
    CONSTRAINT FK_semilla_tienda   FOREIGN KEY (codigo_tienda)
        REFERENCES dim.tienda (codigo_tienda),
    CONSTRAINT CK_semilla_perfil   CHECK (perfil IN ('Estrella','Normal','Rezagado','Baja actividad'))
);
GO

INSERT INTO stg.vendedor_semilla
    (codigo_vendedor, nombre_completo, codigo_tienda, cargo, perfil, factor_productividad)
VALUES
-- T-001 Piura Centro
('V-001','Carlos Alberto Ramírez Vega',      'T-001','Asesor senior',   'Estrella', 1.60),
('V-002','Lucía Fernanda Torres Medina',     'T-001','Asesor comercial','Normal',   1.05),
('V-003','Jorge Luis Castillo Ríos',         'T-001','Asesor comercial','Normal',   0.95),
('V-004','Mariela Soto Chávez',              'T-001','Asesor comercial','Normal',   1.10),
('V-005','Diego Armando Paredes León',       'T-001','Asesor comercial','Rezagado', 0.60),
-- T-002 Piura Mall Norte
('V-006','Andrea Valeria Quispe Huamán',     'T-002','Asesor senior',   'Estrella', 1.70),
('V-007','Renzo Gabriel Flores Alva',        'T-002','Asesor senior',   'Estrella', 1.50),
('V-008','Katherine Díaz Montalvo',          'T-002','Asesor comercial','Normal',   1.15),
('V-009','Luis Miguel Cárdenas Pinto',       'T-002','Asesor comercial','Normal',   1.05),
('V-010','Rosa Elena Mendoza Ruiz',          'T-002','Asesor comercial','Normal',   1.00),
-- T-003 Piura Sur
('V-011','Hugo Sebastián Navarro Aguirre',   'T-003','Asesor comercial','Rezagado', 0.55),
('V-012','Paola Andrea Salazar Vilca',       'T-003','Asesor comercial','Rezagado', 0.70),
('V-013','Víctor Raúl Herrera Luna',         'T-003','Asesor comercial','Normal',   0.90),
-- T-004 Castilla
('V-014','Milagros Del Pilar Zapata Neira',  'T-004','Asesor senior',   'Normal',   1.10),
('V-015','Cristian Joel Ochoa Farfán',       'T-004','Asesor comercial','Normal',   1.00),
('V-016','Fiorella Gutiérrez Sandoval',      'T-004','Asesor comercial','Normal',   0.95),
('V-017','Eduardo Martín Palacios Ugarte',   'T-004','Asesor comercial','Rezagado', 0.65),
-- T-005 Sullana Centro
('V-018','Gladys Marleny Rojas Cevallos',    'T-005','Asesor senior',   'Estrella', 1.45),
('V-019','Anthony Brandon Vásquez Tello',    'T-005','Asesor comercial','Normal',   1.05),
('V-020','Yessenia Carbajal Mogollón',       'T-005','Asesor comercial','Normal',   1.00),
('V-021','Pedro Pablo Sánchez Ordinola',     'T-005','Asesor comercial','Normal',   0.95),
-- T-006 Sullana Mall
('V-022','Natalia Isabel Córdova Reyes',     'T-006','Asesor senior',   'Normal',   1.15),
('V-023','Marco Antonio Alvarado Sullón',    'T-006','Asesor comercial','Normal',   1.05),
('V-024','Daniela Stefany Chunga Peña',      'T-006','Asesor comercial','Normal',   1.00),
('V-025','Jesús David Anchundia Calle',      'T-006','Asesor comercial','Normal',   0.90),
('V-026','Karen Liliana Montero Ato',        'T-006','Asesor comercial','Rezagado', 0.60),
-- T-007 Paita
('V-027','Wilmer Enrique Távara Alcas',      'T-007','Asesor comercial','Rezagado', 0.50),
('V-028','Juana Rosario Chira Yarlequé',     'T-007','Asesor comercial','Normal',   0.85),
('V-029','Álvaro Jesús Seminario Ramos',     'T-007','Asesor comercial','Rezagado', 0.65),
-- T-008 Talara
('V-030','Sandra Patricia Albán Quiroga',    'T-008','Asesor senior',   'Normal',   1.10),
('V-031','Roberto Carlos Zeta Imán',         'T-008','Asesor comercial','Normal',   1.00),
('V-032','Evelyn Johana Farías Lizano',      'T-008','Asesor comercial','Normal',   0.95),
('V-033','Brayan Smith Ruiz Maza',           'T-008','Asesor comercial','Rezagado', 0.70),
-- T-009 Chulucanas
('V-034','Nelly Soledad Jiménez Cruz',       'T-009','Asesor comercial','Rezagado', 0.60),
('V-035','Fabián Ernesto Cruz Neyra',        'T-009','Asesor comercial','Normal',   0.90),
('V-036','Ingrid Tatiana Calderón Panta',    'T-009','Asesor comercial','Rezagado', 0.55),
-- T-010 Tumbes Centro
('V-037','Maribel Cecilia Cunya Rosales',    'T-010','Asesor senior',   'Normal',   1.10),
('V-038','Joel Ricardo Ramos Heredia',       'T-010','Asesor comercial','Normal',   1.00),
('V-039','Alejandra Nicole Gonzales Ruiz',   'T-010','Asesor comercial','Normal',   0.95),
('V-040','Gianfranco Neyra Aponte',          'T-010','Asesor comercial','Normal',   0.90),
-- T-011 Tumbes Mall
('V-041','Teresa Johana Bances Arévalo',     'T-011','Asesor senior',   'Normal',   1.15),
('V-042','Franklin Edwin Pozo Cabrejos',     'T-011','Asesor comercial','Normal',   1.05),
('V-043','Miriam Alexandra Larrea Silupú',   'T-011','Asesor comercial','Normal',   1.00),
('V-044','Sergio Andrés Burga Nole',         'T-011','Asesor comercial','Rezagado', 0.65),
-- T-012 Chiclayo Centro
('V-045','Claudia Beatriz Fernández Lozada', 'T-012','Asesor senior',   'Estrella', 1.75),
('V-046','Orlando Jesús Tarrillo Bravo',     'T-012','Asesor comercial','Estrella', 1.45),
('V-047','Pamela Rocío Llontop Sánchez',     'T-012','Asesor comercial','Normal',   1.10),
('V-048','Henry Wilder Campos Muro',         'T-012','Asesor comercial','Normal',   1.05),
-- T-013 Chiclayo Mall
('V-049','Sofía Alejandra Chávarry Díaz',    'T-013','Asesor senior',   'Normal',   1.20),
('V-050','Raúl Fernando Santamaría Núñez',   'T-013','Asesor comercial','Normal',   1.00),
('V-051','Lizbeth Carolina Ayasta Cieza',    'T-013','Asesor comercial','Normal',   0.95),
('V-052','Omar Alexis Monteza Gil',          'T-013','Asesor comercial','Rezagado', 0.60),
-- T-014 Trujillo Centro
('V-053','Valeria Estefanía Arroyo Lescano', 'T-014','Asesor senior',   'Normal',   1.15),
('V-054','Jhon Anderson Sifuentes Polo',     'T-014','Asesor comercial','Normal',   1.05),
('V-055','Yuliana Mercedes Rodríguez Ñique', 'T-014','Asesor comercial','Normal',   1.00),
('V-056','Kevin Joaquín Liñán Cabanillas',   'T-014','Asesor comercial','Baja actividad', 0.25),
-- T-015 Trujillo Mall
('V-057','Camila Fernanda Zavaleta Paredes', 'T-015','Asesor senior',   'Estrella', 1.55),
('V-058','Ricardo Manuel Gamarra Vera',      'T-015','Asesor comercial','Normal',   1.05),
('V-059','Stephanie Lucero Vargas Alayo',    'T-015','Asesor comercial','Normal',   1.00),
('V-060','Aldo Giancarlo Espejo Reyes',      'T-015','Asesor comercial','Normal',   0.95);
GO



-- V-021: renunció a fin de septiembre ? sin ventas en octubre y marcado como inactivo en planilla
UPDATE stg.vendedor_semilla
SET activo = 0, activo_oct = 0
WHERE codigo_vendedor = 'V-021';

-- V-028: licencia en septiembre ? sin ventas ese mes, pero sigue en planilla
UPDATE stg.vendedor_semilla
SET activo_sep = 0
WHERE codigo_vendedor = 'V-028';

-- V-040: ingresó el 2 de septiembre ? sin ventas en agosto
UPDATE stg.vendedor_semilla
SET activo_ago = 0, ingreso_fijo = '2026-09-02'
WHERE codigo_vendedor = 'V-040';
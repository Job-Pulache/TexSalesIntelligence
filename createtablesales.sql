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
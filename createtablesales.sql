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
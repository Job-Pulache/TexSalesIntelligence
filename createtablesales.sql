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
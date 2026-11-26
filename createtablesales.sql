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
DROP TABLE IF EXISTS product;
DROP TABLE IF EXISTS user;

CREATE TABLE user (
    id               VARCHAR(255)    NOT NULL,
    username         VARCHAR(255)    NOT NULL,
    email            VARCHAR(255)    NOT NULL,
    PRIMARY KEY (id),
    UNIQUE KEY uk_username (username)
);

CREATE TABLE product (
    id               VARCHAR(255)    NOT NULL,
    name             VARCHAR(255)    NOT NULL,
    price            FLOAT(8)        NOT NULL,
    image_path       VARCHAR(500)    DEFAULT NULL,
    PRIMARY KEY (id)
);

CREATE INDEX idx_user_email ON user(email);
CREATE INDEX idx_product_name ON product(name);
CREATE INDEX idx_product_price ON apdev.product(price);
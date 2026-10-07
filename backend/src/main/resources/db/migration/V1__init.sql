-- 1. USERS
CREATE TABLE users (
                       id            BIGINT AUTO_INCREMENT PRIMARY KEY,
                       email         VARCHAR(255) NOT NULL UNIQUE,
                       password_hash VARCHAR(255) NOT NULL,
                       name          VARCHAR(100) NOT NULL,
                       created_at    DATETIME(6)  NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. CUSTOMERS
CREATE TABLE customers (
                           id           CHAR(36)     PRIMARY KEY,
                           user_id      BIGINT       NOT NULL,
                           name         VARCHAR(150) NOT NULL,
                           contact_info TEXT,
                           created_at   DATETIME(6)  NOT NULL,
                           updated_at   DATETIME(6)  NOT NULL,
                           deleted_at   DATETIME(6)  NULL,
                           CONSTRAINT fk_customers_user
                               FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. SITES
CREATE TABLE sites (
                       id          CHAR(36)     PRIMARY KEY,
                       customer_id CHAR(36)     NOT NULL,
                       site_name   VARCHAR(150) NOT NULL,
                       address     TEXT,
                       created_at  DATETIME(6)  NOT NULL,
                       updated_at  DATETIME(6)  NOT NULL,
                       deleted_at  DATETIME(6)  NULL,
                       CONSTRAINT fk_sites_customer
                           FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. FIELD NOTES
CREATE TABLE field_notes (
                             id          CHAR(36)      PRIMARY KEY,
                             site_id     CHAR(36)      NOT NULL,
                             title       VARCHAR(200)  NOT NULL,
                             description TEXT,
                             latitude    DECIMAL(10,8) NULL,
                             longitude   DECIMAL(11,8) NULL,
                             noted_at    DATETIME(6)   NOT NULL,
                             status      VARCHAR(50)   NOT NULL DEFAULT 'OPEN',
                             photo_path  VARCHAR(255)  NULL,
                             created_at  DATETIME(6)   NOT NULL,
                             updated_at  DATETIME(6)   NOT NULL,
                             deleted_at  DATETIME(6)   NULL,
                             CONSTRAINT fk_field_notes_site
                                 FOREIGN KEY (site_id) REFERENCES sites(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- INDEXES (query + sync)
CREATE INDEX idx_customers_user_id    ON customers(user_id);
CREATE INDEX idx_customers_updated_at ON customers(updated_at);

CREATE INDEX idx_sites_customer_id ON sites(customer_id);
CREATE INDEX idx_sites_updated_at  ON sites(updated_at);

CREATE INDEX idx_field_notes_site_id    ON field_notes(site_id);
CREATE INDEX idx_field_notes_status     ON field_notes(status);
CREATE INDEX idx_field_notes_updated_at ON field_notes(updated_at);
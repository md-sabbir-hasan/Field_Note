ALTER TABLE customers   ADD COLUMN client_updated_at DATETIME(6) NULL;
ALTER TABLE sites       ADD COLUMN client_updated_at DATETIME(6) NULL;
ALTER TABLE field_notes ADD COLUMN client_updated_at DATETIME(6) NULL;

-- Existing rows get their server time as the starting value.
UPDATE customers   SET client_updated_at = updated_at;
UPDATE sites       SET client_updated_at = updated_at;
UPDATE field_notes SET client_updated_at = updated_at;

ALTER TABLE customers   MODIFY client_updated_at DATETIME(6) NOT NULL;
ALTER TABLE sites       MODIFY client_updated_at DATETIME(6) NOT NULL;
ALTER TABLE field_notes MODIFY client_updated_at DATETIME(6) NOT NULL;
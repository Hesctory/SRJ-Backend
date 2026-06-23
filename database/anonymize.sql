-- =============================================================================
-- anonymize.sql
-- Scrubs all real personal/credential data so the database can be shipped
-- as a portable seed. Run against a *throwaway copy* of the DB, never prod.
--
-- What it removes:
--   users           : real login email + Argon2 password hash + name/phone
--   person           : names, national-ID numbers, emails, phones, addresses
--   familiars        : occupation / workplace free-text
--   staff_members    : spouse identity, previous institution, free-text comment
--   employment_contract : real salary figures
--
-- After running, the seed admin can log in with:
--   email:    admin@srj.local
--   password: Admin123!
-- =============================================================================

BEGIN;

-- Login account ------------------------------------------------------------
UPDATE users SET
    names             = 'Admin',
    paternal_lastname = 'User',
    maternal_lastname = 'User',
    email             = 'admin@srj.local',
    phone             = '900000000',
    hashed_password   = '$argon2id$v=19$m=65536,t=3,p=1$LRGr4HvFQ3kVORVDmjawgQ$8UHQ8kN3AQ5mXkROcgCBOGcjYQmUHA5E9TaBPRr2wF0';

-- People (students, familiars, staff all share this table) -----------------
UPDATE person SET
    names             = 'Nombre' || id,
    paternal_lastname = 'Apellido' || id,
    maternal_lastname = 'Materno' || id,
    id_document_number = lpad(id::text, 8, '0'),
    address           = 'Direccion de prueba ' || id,
    email             = CASE WHEN email          IS NOT NULL THEN 'persona' || id || '@example.test' END,
    cell_phone        = CASE WHEN cell_phone     IS NOT NULL THEN '9' || lpad(id::text, 8, '0') END,
    landline_phone    = CASE WHEN landline_phone IS NOT NULL THEN '0' || lpad(id::text, 8, '0') END;

-- Familiar free-text -------------------------------------------------------
UPDATE familiars SET
    occupation = CASE WHEN occupation IS NOT NULL THEN 'Ocupacion de prueba' END,
    workplace  = CASE WHEN workplace  IS NOT NULL THEN 'Centro de trabajo de prueba' END;

-- Staff PII ----------------------------------------------------------------
UPDATE staff_members SET
    previous_institution   = CASE WHEN previous_institution   IS NOT NULL THEN 'Institucion de prueba' END,
    spouse_name            = CASE WHEN spouse_name            IS NOT NULL THEN 'Conyuge ' || person_id END,
    spouse_document_number = CASE WHEN spouse_document_number IS NOT NULL THEN lpad(person_id::text, 8, '0') END,
    spouse_occupation      = CASE WHEN spouse_occupation      IS NOT NULL THEN 'Ocupacion de prueba' END,
    comment                = NULL;

-- Salaries -----------------------------------------------------------------
UPDATE employment_contract SET salary = 1000.00;

COMMIT;

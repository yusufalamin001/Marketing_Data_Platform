-- Unity Catalog permissions for the dbt service principal.
-- The principal runs CI, staging and production. It gets read access to raw
-- data and the right to create its own schemas in the environment catalogs.
-- Nothing here lets it modify raw data or create catalogs.
--
-- Run once by a catalog owner. Replace the placeholder with the application ID.

-- Raw data: read only, limited to the two schemas this project uses
GRANT USE CATALOG ON CATALOG bronze_production TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE SCHEMA, SELECT ON SCHEMA bronze_production.facebook_ads TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE SCHEMA, SELECT ON SCHEMA bronze_production.snapchat_ads TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;

-- Environments the principal builds into. dbt creates the schemas itself, and a
-- schema's creator owns it, so no table-level grants are needed on these.
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG ci_development    TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG silver_staging    TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG gold_staging      TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG silver_production TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;
GRANT USE CATALOG, CREATE SCHEMA ON CATALOG gold_production   TO `<SERVICE_PRINCIPAL_APPLICATION_ID>`;

-- Deliberately not granted: CREATE CATALOG on the metastore, and any write
-- privilege on bronze_production.

-- The developer can read what CI builds
GRANT USE CATALOG, USE SCHEMA, SELECT ON CATALOG ci_development TO `<YOUR_EMAIL>`;
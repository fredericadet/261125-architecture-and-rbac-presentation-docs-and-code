-- =====================================================================================
-- RBAC TEST SETUP SCRIPT
-- Contexte : Meeting Flake du 25 novembre 2026 dans les locaux d'APICIL
--
-- Pattern retenu : "Single Account, Environment Admins" (Pattern A du skill RBAC)
--   Layer 1 : OOB Account Roles (ACCOUNTADMIN / SYSADMIN / SECURITYADMIN / USERADMIN)
--   Layer 2 : Environment Admin Roles (DEV_* / PRD_*)
--   Layer 5 : Database Access Roles (DB_R / DB_RW / DB_C) - Database Roles
--   Layer 6 : Schema Access Roles (<schema>_R / _RW / _C) - Database Roles
--   + Rôles fonctionnels (personas) : ANALYST_RO, ANALYST_RW, DATA_ENGINEER (par environnement)
--
-- Portée : jeu de test TEST_RBAC_DB.TEST_SCHEMA, décliné sur 2 environnements logiques
--          (DEV et PRD) afin de valider la séparation Dev/Prod dans le même compte.
--
-- IMPORTANT : Script généré pour revue. NE PAS EXÉCUTER sans relecture et validation.
-- Convention : chaque section peut être exécutée indépendamment une fois les sections
-- précédentes validées. Les blocs DEV et PRD sont strictement symétriques.
-- =====================================================================================


-- =====================================================================================
-- SECTION 0 : Pré-requis - rôle d'exécution
-- =====================================================================================
-- Les CREATE ROLE sont effectués par USERADMIN (séparation administration des rôles /
-- administration des objets). Les CREATE DATABASE/WAREHOUSE sont effectués par SYSADMIN
-- puis l'ownership est transférée aux rôles délégués d'environnement.


-- =====================================================================================
-- SECTION 1 : Rôles d'accès au niveau compte (Access Roles) - optionnel pour un jeu de test
-- =====================================================================================
-- Non requis pour ce périmètre de test (pas de tâches, pas de masking policies, pas de
-- tags à ce stade). Section volontairement omise - voir skill `oob-account-roles` si
-- besoin futur de EXECUTE TASK / APPLY TAG / APPLY MASKING POLICY etc.


-- =====================================================================================
-- SECTION 2 : Rôles d'administration d'environnement (Layer 2)
-- =====================================================================================
-- Un jeu de rôles par environnement : <ENV>_SYSADMIN (possède DB/WH),
-- <ENV>_RBAC (gère les grants), <ENV>_READER (accès lecture agrégé pour l'environnement).

USE ROLE USERADMIN;

-- --- DEV ---
CREATE ROLE IF NOT EXISTS DEV_SYSADMIN COMMENT = 'Admin délégué environnement DEV - possède DB/WH de test';
CREATE ROLE IF NOT EXISTS DEV_RBAC     COMMENT = 'Gouvernance des accès (grants) pour l''environnement DEV';
CREATE ROLE IF NOT EXISTS DEV_READER   COMMENT = 'Accès lecture agrégé environnement DEV';

-- --- PRD ---
CREATE ROLE IF NOT EXISTS PRD_SYSADMIN COMMENT = 'Admin délégué environnement PRD - possède DB/WH de test';
CREATE ROLE IF NOT EXISTS PRD_RBAC     COMMENT = 'Gouvernance des accès (grants) pour l''environnement PRD';
CREATE ROLE IF NOT EXISTS PRD_READER   COMMENT = 'Accès lecture agrégé environnement PRD';

USE ROLE SECURITYADMIN;

-- READER remonte vers SYSADMIN de l'environnement (qui hérite donc de la lecture + warehouse)
GRANT ROLE DEV_READER TO ROLE DEV_SYSADMIN;
GRANT ROLE PRD_READER TO ROLE PRD_SYSADMIN;

-- Les rôles d'environnement remontent vers les rôles OOB pour que l'admin central garde l'accès
GRANT ROLE DEV_SYSADMIN TO ROLE SYSADMIN;
GRANT ROLE DEV_RBAC     TO ROLE SECURITYADMIN;
GRANT ROLE DEV_READER   TO ROLE SYSADMIN;

GRANT ROLE PRD_SYSADMIN TO ROLE SYSADMIN;
GRANT ROLE PRD_RBAC     TO ROLE SECURITYADMIN;
GRANT ROLE PRD_READER   TO ROLE SYSADMIN;


-- =====================================================================================
-- SECTION 3 : Warehouses de test (un par environnement)
-- =====================================================================================

USE ROLE SYSADMIN;

CREATE WAREHOUSE IF NOT EXISTS DEV_TEST_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse de test - environnement DEV';

GRANT OWNERSHIP ON WAREHOUSE DEV_TEST_WH TO ROLE DEV_SYSADMIN COPY CURRENT GRANTS;

CREATE WAREHOUSE IF NOT EXISTS PRD_TEST_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE
  COMMENT = 'Warehouse de test - environnement PRD';

GRANT OWNERSHIP ON WAREHOUSE PRD_TEST_WH TO ROLE PRD_SYSADMIN COPY CURRENT GRANTS;


-- =====================================================================================
-- SECTION 4 : Bases de données de test (une par environnement)
-- =====================================================================================
-- Convention de nommage : <ENV>_<NOM_BASE>

USE ROLE SYSADMIN;

CREATE DATABASE IF NOT EXISTS DEV_TEST_RBAC_DB COMMENT = 'Jeu de test RBAC - environnement DEV';
GRANT OWNERSHIP ON DATABASE DEV_TEST_RBAC_DB TO ROLE DEV_SYSADMIN COPY CURRENT GRANTS;

CREATE DATABASE IF NOT EXISTS PRD_TEST_RBAC_DB COMMENT = 'Jeu de test RBAC - environnement PRD';
GRANT OWNERSHIP ON DATABASE PRD_TEST_RBAC_DB TO ROLE PRD_SYSADMIN COPY CURRENT GRANTS;


-- =====================================================================================
-- SECTION 5 : Database Access Roles (Layer 5) - DB_R / DB_RW / DB_C par base
-- =====================================================================================
-- Ces Database Roles n'ont AUCUN privilège direct : elles agrègent les Schema Access
-- Roles (Section 6). Elles sont créées par le SYSADMIN d'environnement puis la propriété
-- est transférée au rôle RBAC de l'environnement pour séparer administration et gouvernance.

-- --- DEV ---
USE ROLE DEV_SYSADMIN;
USE DATABASE DEV_TEST_RBAC_DB;

CREATE DATABASE ROLE IF NOT EXISTS DB_R;
CREATE DATABASE ROLE IF NOT EXISTS DB_RW;
CREATE DATABASE ROLE IF NOT EXISTS DB_C;

GRANT OWNERSHIP ON DATABASE ROLE DB_R  TO ROLE DEV_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE ROLE DB_RW TO ROLE DEV_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE ROLE DB_C  TO ROLE DEV_RBAC COPY CURRENT GRANTS;

-- --- PRD ---
USE ROLE PRD_SYSADMIN;
USE DATABASE PRD_TEST_RBAC_DB;

CREATE DATABASE ROLE IF NOT EXISTS DB_R;
CREATE DATABASE ROLE IF NOT EXISTS DB_RW;
CREATE DATABASE ROLE IF NOT EXISTS DB_C;

GRANT OWNERSHIP ON DATABASE ROLE DB_R  TO ROLE PRD_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE ROLE DB_RW TO ROLE PRD_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON DATABASE ROLE DB_C  TO ROLE PRD_RBAC COPY CURRENT GRANTS;


-- =====================================================================================
-- SECTION 5bis : Délégation des privilèges structurels à RBAC
-- =====================================================================================
-- DEV_RBAC/PRD_RBAC possèdent les Database Access Roles mais pas la base elle-même
-- (ownership = <ENV>_SYSADMIN, Section 4). Sans ces grants :
--   - CREATE SCHEMA en Section 6 échoue ("must have CREATE SCHEMA granted")
--   - CREATE DATABASE ROLE en Section 6 échoue aussi ("must have CREATE DATABASE ROLE
--     granted") car TEST_SCHEMA_R/_RW/_C sont de NOUVELLES Database Roles créées dans
--     la base - ce privilège est au niveau DATABASE, pas au niveau SCHEMA.

USE ROLE DEV_SYSADMIN;
GRANT CREATE SCHEMA ON DATABASE DEV_TEST_RBAC_DB TO ROLE DEV_RBAC;
GRANT CREATE DATABASE ROLE ON DATABASE DEV_TEST_RBAC_DB TO ROLE DEV_RBAC;

USE ROLE PRD_SYSADMIN;
GRANT CREATE SCHEMA ON DATABASE PRD_TEST_RBAC_DB TO ROLE PRD_RBAC;
GRANT CREATE DATABASE ROLE ON DATABASE PRD_TEST_RBAC_DB TO ROLE PRD_RBAC;


-- =====================================================================================
-- SECTION 6 : Schéma de test + Schema Access Roles (Layer 6) - TEST_SCHEMA
-- =====================================================================================
-- MANAGED ACCESS obligatoire : seul le propriétaire du schéma peut accorder l'accès aux
-- objets qu'il contient (empêche les créateurs d'objets de contourner la gouvernance).

-- --- DEV ---
USE ROLE DEV_RBAC;
USE DATABASE DEV_TEST_RBAC_DB;

CREATE SCHEMA IF NOT EXISTS TEST_SCHEMA WITH MANAGED ACCESS COMMENT = 'Schéma de test DEV';

-- READ (TEST_SCHEMA_R)
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_R;
GRANT USAGE, MONITOR ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON ALL TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON ALL VIEWS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;

-- READ-WRITE (TEST_SCHEMA_RW)
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_RW;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;

-- CREATE (TEST_SCHEMA_C) - octroie le DDL, ne donne jamais l'ownership des objets créés
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_C;
GRANT CREATE TABLE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE VIEW ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE FILE FORMAT ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE SEQUENCE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE STAGE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;

-- Hiérarchie : C hérite de RW, RW hérite de R
GRANT DATABASE ROLE TEST_SCHEMA_R  TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT DATABASE ROLE TEST_SCHEMA_RW TO DATABASE ROLE TEST_SCHEMA_C;

-- Agrégation dans les Database Access Roles (Section 5)
GRANT DATABASE ROLE TEST_SCHEMA_R  TO DATABASE ROLE DB_R;
GRANT DATABASE ROLE TEST_SCHEMA_RW TO DATABASE ROLE DB_RW;
GRANT DATABASE ROLE TEST_SCHEMA_C  TO DATABASE ROLE DB_C;


-- --- PRD --- (strictement symétrique à DEV)
USE ROLE PRD_RBAC;
USE DATABASE PRD_TEST_RBAC_DB;

CREATE SCHEMA IF NOT EXISTS TEST_SCHEMA WITH MANAGED ACCESS COMMENT = 'Schéma de test PRD';

-- READ (TEST_SCHEMA_R)
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_R;
GRANT USAGE, MONITOR ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON ALL TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON ALL VIEWS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT USAGE ON ALL FUNCTIONS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON FUTURE TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT SELECT ON FUTURE VIEWS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;
GRANT USAGE ON FUTURE FUNCTIONS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_R;

-- READ-WRITE (TEST_SCHEMA_RW)
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_RW;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON ALL FILE FORMATS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT INSERT, UPDATE, DELETE, TRUNCATE ON FUTURE TABLES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON FUTURE SEQUENCES IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT USAGE ON FUTURE FILE FORMATS IN SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_RW;

-- CREATE (TEST_SCHEMA_C)
CREATE DATABASE ROLE IF NOT EXISTS TEST_SCHEMA_C;
GRANT CREATE TABLE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE VIEW ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE FILE FORMAT ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE SEQUENCE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;
GRANT CREATE STAGE ON SCHEMA TEST_SCHEMA TO DATABASE ROLE TEST_SCHEMA_C;

-- Hiérarchie
GRANT DATABASE ROLE TEST_SCHEMA_R  TO DATABASE ROLE TEST_SCHEMA_RW;
GRANT DATABASE ROLE TEST_SCHEMA_RW TO DATABASE ROLE TEST_SCHEMA_C;

-- Agrégation
GRANT DATABASE ROLE TEST_SCHEMA_R  TO DATABASE ROLE DB_R;
GRANT DATABASE ROLE TEST_SCHEMA_RW TO DATABASE ROLE DB_RW;
GRANT DATABASE ROLE TEST_SCHEMA_C  TO DATABASE ROLE DB_C;


-- =====================================================================================
-- SECTION 7 : Rôles fonctionnels / personas (par environnement)
-- =====================================================================================
-- Personas demandés : ANALYST_RO (lecture), ANALYST_RW (lecture/écriture), DATA_ENGINEER
-- (DDL + lecture/écriture). Déclinés par environnement pour respecter la séparation
-- logique DEV/PRD (un utilisateur DEV ne doit jamais recevoir le rôle PRD par erreur).

USE ROLE USERADMIN;

-- --- DEV ---
CREATE ROLE IF NOT EXISTS DEV_ANALYST_RO    COMMENT = 'Persona Analyste lecture seule - DEV';
CREATE ROLE IF NOT EXISTS DEV_ANALYST_RW    COMMENT = 'Persona Analyste lecture/écriture - DEV';
CREATE ROLE IF NOT EXISTS DEV_DATA_ENGINEER COMMENT = 'Persona Data Engineer (DDL) - DEV';

-- --- PRD ---
CREATE ROLE IF NOT EXISTS PRD_ANALYST_RO    COMMENT = 'Persona Analyste lecture seule - PRD';
CREATE ROLE IF NOT EXISTS PRD_ANALYST_RW    COMMENT = 'Persona Analyste lecture/écriture - PRD';
CREATE ROLE IF NOT EXISTS PRD_DATA_ENGINEER COMMENT = 'Persona Data Engineer (DDL) - PRD';

-- Transfert de propriété au rôle RBAC de l'environnement (gouvernance des accès)
USE ROLE SECURITYADMIN;

GRANT OWNERSHIP ON ROLE DEV_ANALYST_RO    TO ROLE DEV_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROLE DEV_ANALYST_RW    TO ROLE DEV_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROLE DEV_DATA_ENGINEER TO ROLE DEV_RBAC COPY CURRENT GRANTS;

GRANT OWNERSHIP ON ROLE PRD_ANALYST_RO    TO ROLE PRD_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROLE PRD_ANALYST_RW    TO ROLE PRD_RBAC COPY CURRENT GRANTS;
GRANT OWNERSHIP ON ROLE PRD_DATA_ENGINEER TO ROLE PRD_RBAC COPY CURRENT GRANTS;


-- =====================================================================================
-- SECTION 8 : Rattachement des Database Access Roles + Warehouse aux rôles fonctionnels
-- =====================================================================================

USE ROLE DEV_RBAC;
GRANT DATABASE ROLE DEV_TEST_RBAC_DB.DB_R  TO ROLE DEV_ANALYST_RO;
GRANT DATABASE ROLE DEV_TEST_RBAC_DB.DB_RW TO ROLE DEV_ANALYST_RW;
GRANT DATABASE ROLE DEV_TEST_RBAC_DB.DB_C  TO ROLE DEV_DATA_ENGINEER;

USE ROLE PRD_RBAC;
GRANT DATABASE ROLE PRD_TEST_RBAC_DB.DB_R  TO ROLE PRD_ANALYST_RO;
GRANT DATABASE ROLE PRD_TEST_RBAC_DB.DB_RW TO ROLE PRD_ANALYST_RW;
GRANT DATABASE ROLE PRD_TEST_RBAC_DB.DB_C  TO ROLE PRD_DATA_ENGINEER;

-- Accès warehouse : chaque persona apporte son propre compute (pas de bundling données/compute)
USE ROLE DEV_SYSADMIN;
GRANT USAGE ON WAREHOUSE DEV_TEST_WH TO ROLE DEV_ANALYST_RO;
GRANT USAGE ON WAREHOUSE DEV_TEST_WH TO ROLE DEV_ANALYST_RW;
GRANT USAGE ON WAREHOUSE DEV_TEST_WH TO ROLE DEV_DATA_ENGINEER;

USE ROLE PRD_SYSADMIN;
GRANT USAGE ON WAREHOUSE PRD_TEST_WH TO ROLE PRD_ANALYST_RO;
GRANT USAGE ON WAREHOUSE PRD_TEST_WH TO ROLE PRD_ANALYST_RW;
GRANT USAGE ON WAREHOUSE PRD_TEST_WH TO ROLE PRD_DATA_ENGINEER;

-- Les rôles ANALYST_RO remontent vers le READER d'environnement (visibilité centrale)
USE ROLE SECURITYADMIN;
GRANT ROLE DEV_ANALYST_RO TO ROLE DEV_READER;
GRANT ROLE PRD_ANALYST_RO TO ROLE PRD_READER;


-- =====================================================================================
-- SECTION 9 : Rattachement des rôles fonctionnels aux utilisateurs de test
-- =====================================================================================
-- Remplacer <USER_...> par les logins réels existants dans le compte avant exécution.

USE ROLE SECURITYADMIN;

-- Exemple d'attribution (à adapter) :
-- GRANT ROLE DEV_ANALYST_RO    TO USER <USER_ANALYSTE_DEV>;
-- GRANT ROLE DEV_ANALYST_RW    TO USER <USER_ANALYSTE_RW_DEV>;
-- GRANT ROLE DEV_DATA_ENGINEER TO USER <USER_DATA_ENGINEER_DEV>;
-- GRANT ROLE PRD_ANALYST_RO    TO USER <USER_ANALYSTE_PRD>;

-- Définir un rôle par défaut (exemple) :
-- ALTER USER <USER_ANALYSTE_DEV> SET DEFAULT_ROLE = 'DEV_ANALYST_RO', DEFAULT_WAREHOUSE = 'DEV_TEST_WH';


-- =====================================================================================
-- SECTION 9bis : Rattachement des groupes SCIM (IdP) aux rôles
-- =====================================================================================
-- Le provisioning SCIM (Entra ID / Okta) ne gère QUE des grants ROLE -> USER sur des
-- Account Roles. Il NE PEUT PAS cibler une Database Role (DB_R/DB_RW/DB_C,
-- TEST_SCHEMA_R/_RW/_C) : ces rôles ne sont pas assignables à un utilisateur, uniquement
-- grantables à d'autres rôles. Le SEUL point d'attache valide pour un groupe SCIM est
-- donc un rôle fonctionnel (persona) de la Section 7 - jamais une Database Role, jamais
-- un rôle d'administration (<ENV>_SYSADMIN / <ENV>_RBAC).
--
-- Mapping attendu côté IdP (1 groupe = 1 rôle, pas de bundling) :
--   SNOW-DEV-ANALYST-RO       -> DEV_ANALYST_RO
--   SNOW-DEV-ANALYST-RW       -> DEV_ANALYST_RW
--   SNOW-DEV-DATA-ENGINEER    -> DEV_DATA_ENGINEER
--   SNOW-PRD-ANALYST-RO       -> PRD_ANALYST_RO
--   SNOW-PRD-ANALYST-RW       -> PRD_ANALYST_RW
--   SNOW-PRD-DATA-ENGINEER    -> PRD_DATA_ENGINEER
--
-- Une fois le mapping configuré côté IdP, SCIM pousse automatiquement l'équivalent de :
--   GRANT ROLE DEV_ANALYST_RO TO USER <user_synchronisé>;
-- en fonction de l'appartenance aux groupes - plus besoin de GRANT manuel (Section 9).
--
-- Si un utilisateur doit cumuler plusieurs personas (ex: DEV + PRD, ou plusieurs
-- domaines), ne pas créer de rôle combiné : activer les rôles secondaires côté session
-- (voir skill `secondary-roles`) :
-- ALTER USER <user_synchronisé> SET DEFAULT_SECONDARY_ROLES = ('ALL');
--
-- Ne JAMAIS wrapper un rôle OOB (SYSADMIN, SECURITYADMIN, ACCOUNTADMIN...) dans un rôle
-- "SCIM-friendly" : si des administrateurs doivent recevoir ces rôles via SCIM, cela doit
-- être documenté comme exception gérée hors de ce pattern (voir skill `oob-account-roles`).


-- =====================================================================================
-- SECTION 9ter : Auto-attribution temporaire pour valider le script (opérateur courant)
-- =====================================================================================
-- Les personas n'ont été grantées à AUCUN utilisateur réel (Section 9 = placeholders
-- commentés). Pour pouvoir exécuter la Section 10 (jeu de données de test) sans attendre
-- un vrai utilisateur de test, on s'auto-attribue temporairement DEV_DATA_ENGINEER.
-- EN PRODUCTION : remplacer par un vrai GRANT ROLE ... TO USER <user> (Section 9) ou par
-- le provisioning SCIM (Section 9bis) - ne pas garder cette auto-attribution.

USE ROLE SECURITYADMIN;
SET currentUser = CURRENT_USER();
GRANT ROLE DEV_ANALYST_RO    TO USER IDENTIFIER($currentUser);
GRANT ROLE DEV_ANALYST_RW    TO USER IDENTIFIER($currentUser);
GRANT ROLE DEV_DATA_ENGINEER TO USER IDENTIFIER($currentUser);


-- =====================================================================================
-- SECTION 10 : Jeu de données de test (pour valider le RBAC)
-- =====================================================================================
-- Créé avec le rôle DATA_ENGINEER de DEV : l'objet sera possédé par DEV_DATA_ENGINEER
-- (jamais par la Database Role TEST_SCHEMA_C qui ne doit jamais détenir d'objets).

USE ROLE DEV_DATA_ENGINEER;
USE DATABASE DEV_TEST_RBAC_DB;
USE SCHEMA TEST_SCHEMA;
USE WAREHOUSE DEV_TEST_WH;

CREATE TABLE IF NOT EXISTS CUSTOMERS_TEST (
    CUSTOMER_ID INT,
    CUSTOMER_NAME STRING,
    CREATED_AT TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

INSERT INTO CUSTOMERS_TEST (CUSTOMER_ID, CUSTOMER_NAME) VALUES
    (1, 'Client Test A'),
    (2, 'Client Test B'),
    (3, 'Client Test C');


-- =====================================================================================
-- SECTION 11 : Validation (à exécuter après attribution des rôles aux utilisateurs)
-- =====================================================================================

-- Vérifier la hiérarchie des rôles fonctionnels
SHOW GRANTS TO ROLE DEV_ANALYST_RO;
SHOW GRANTS TO ROLE DEV_ANALYST_RW;
SHOW GRANTS TO ROLE DEV_DATA_ENGINEER;

-- Vérifier les grants sur les Database Access Roles
SHOW GRANTS TO DATABASE ROLE DEV_TEST_RBAC_DB.DB_R;
SHOW GRANTS TO DATABASE ROLE DEV_TEST_RBAC_DB.DB_RW;
SHOW GRANTS TO DATABASE ROLE DEV_TEST_RBAC_DB.DB_C;

-- Test fonctionnel : la persona lecture seule doit voir les données mais pas écrire
-- ATTENTION : désactiver les rôles secondaires, sinon les autres personas attribuées
-- (Section 9ter) apportent leurs privilèges et faussent le test.
USE ROLE DEV_ANALYST_RO;
USE SECONDARY ROLES NONE;
SELECT * FROM DEV_TEST_RBAC_DB.TEST_SCHEMA.CUSTOMERS_TEST;      -- doit réussir
INSERT INTO DEV_TEST_RBAC_DB.TEST_SCHEMA.CUSTOMERS_TEST VALUES (4, 'X', CURRENT_TIMESTAMP()); -- doit échouer

-- Test fonctionnel : la persona lecture/écriture doit pouvoir écrire mais pas créer d'objets
USE ROLE DEV_ANALYST_RW;
USE SECONDARY ROLES NONE;
INSERT INTO DEV_TEST_RBAC_DB.TEST_SCHEMA.CUSTOMERS_TEST VALUES (4, 'Client Test D', CURRENT_TIMESTAMP()); -- doit réussir
CREATE TABLE DEV_TEST_RBAC_DB.TEST_SCHEMA.SHOULD_FAIL (ID INT); -- doit échouer


-- =====================================================================================
-- SECTION 12 (OPTIONNEL) : Nettoyage complet du jeu de test
-- =====================================================================================
-- À exécuter uniquement pour supprimer entièrement le jeu de test. Décommenter pour utiliser.

-- 12.1 - Sortir des rôles/objets de test et rétablir les rôles secondaires dans la session
-- (impossible de supprimer un warehouse ou un rôle en cours d'utilisation dans la session)
-- USE ROLE ACCOUNTADMIN;
-- USE SECONDARY ROLES ALL;
-- USE WAREHOUSE COMPUTE_WH;
--
-- 12.2 - Retirer l'auto-attribution temporaire de la Section 9ter
-- USE ROLE SECURITYADMIN;
-- SET currentUser = CURRENT_USER();
-- REVOKE ROLE DEV_ANALYST_RO    FROM USER IDENTIFIER($currentUser);
-- REVOKE ROLE DEV_ANALYST_RW    FROM USER IDENTIFIER($currentUser);
-- REVOKE ROLE DEV_DATA_ENGINEER FROM USER IDENTIFIER($currentUser);
-- (si la Section 9 a été appliquée à de vrais utilisateurs, révoquer aussi ces grants ;
--  le DROP ROLE ci-dessous les supprime de toute façon)
--
-- 12.3 - Objets (DB = supprime aussi schémas, tables, Database Roles DB_* / TEST_SCHEMA_*)
-- SYSADMIN hérite de DEV_SYSADMIN / PRD_SYSADMIN, propriétaires des DB et WH
-- USE ROLE SYSADMIN;
-- DROP DATABASE IF EXISTS DEV_TEST_RBAC_DB;
-- DROP DATABASE IF EXISTS PRD_TEST_RBAC_DB;
-- DROP WAREHOUSE IF EXISTS DEV_TEST_WH;
-- DROP WAREHOUSE IF EXISTS PRD_TEST_WH;
--
-- 12.4 - Rôles : SECURITYADMIN et non USERADMIN, car les personas appartiennent à
-- <ENV>_RBAC (Section 7), qui remonte vers SECURITYADMIN. USERADMIN n'en est pas
-- propriétaire et le DROP échouerait. Les personas sont supprimées avant leur rôle propriétaire.
-- USE ROLE SECURITYADMIN;
-- DROP ROLE IF EXISTS DEV_ANALYST_RO;
-- DROP ROLE IF EXISTS DEV_ANALYST_RW;
-- DROP ROLE IF EXISTS DEV_DATA_ENGINEER;
-- DROP ROLE IF EXISTS PRD_ANALYST_RO;
-- DROP ROLE IF EXISTS PRD_ANALYST_RW;
-- DROP ROLE IF EXISTS PRD_DATA_ENGINEER;
-- DROP ROLE IF EXISTS DEV_SYSADMIN;
-- DROP ROLE IF EXISTS DEV_RBAC;
-- DROP ROLE IF EXISTS DEV_READER;
-- DROP ROLE IF EXISTS PRD_SYSADMIN;
-- DROP ROLE IF EXISTS PRD_RBAC;
-- DROP ROLE IF EXISTS PRD_READER;
--
-- 12.5 - Rétablir l'activation par défaut des rôles secondaires pour l'utilisateur
-- (désactivée pendant les tests via USE SECONDARY ROLES NONE)
-- USE ROLE USERADMIN;
-- ALTER USER IDENTIFIER($currentUser) SET DEFAULT_SECONDARY_ROLES = ('ALL');
-- UNSET currentUser;
--
-- 12.6 - Vérification
-- SHOW ROLES LIKE 'DEV\\_%';
-- SHOW ROLES LIKE 'PRD\\_%';
-- SHOW DATABASES LIKE '%TEST_RBAC_DB';
-- SHOW WAREHOUSES LIKE '%TEST_WH';
-- SELECT CURRENT_SECONDARY_ROLES();

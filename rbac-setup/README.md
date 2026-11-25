# RBAC Test Setup — TEST_RBAC_DB

Script de démonstration/validation d'une architecture RBAC Snowflake, appliqué à un jeu de données de test. Fichier associé : [`261125-RBAC-setup-for-flake-meeting.sql`](./261125-RBAC-setup-for-flake-meeting.sql).

> ⚠️ **Script généré pour revue.** Il n'a pas été exécuté. Relisez chaque section et remplacez les placeholders avant tout lancement dans le cadre du Meeting Flake du 25 novembre 2026 dans les locaux d'APICIL.

## Objectif

Valider un pattern RBAC "Compte unique avec séparation logique d'environnements" (Pattern A du skill `rbac`), en le déclinant sur deux environnements fictifs **DEV** et **PRD**, avec une base de test (`TEST_RBAC_DB`) et un schéma (`TEST_SCHEMA`).

## Hiérarchie des rôles mise en place

```
OOB Roles (SYSADMIN / SECURITYADMIN / USERADMIN)
    └── Rôles d'administration d'environnement (Layer 2)
        DEV_SYSADMIN / DEV_RBAC / DEV_READER
        PRD_SYSADMIN / PRD_RBAC / PRD_READER
            └── Database Access Roles (Layer 5) — Database Roles
                DB_R / DB_RW / DB_C (un jeu par base DEV/PRD)
                    └── Schema Access Roles (Layer 6) — Database Roles
                        TEST_SCHEMA_R / TEST_SCHEMA_RW / TEST_SCHEMA_C
                            └── Objets du schéma (tables, vues, etc.)

Rôles fonctionnels (personas), rattachés aux Database Access Roles :
    DEV_ANALYST_RO    → DB_R   (lecture seule)
    DEV_ANALYST_RW    → DB_RW  (lecture/écriture)
    DEV_DATA_ENGINEER → DB_C   (DDL)
    PRD_ANALYST_RO / PRD_ANALYST_RW / PRD_DATA_ENGINEER (idem, environnement PRD)
```

| Rôle | Type | Rôle dans la hiérarchie |
|---|---|---|
| `DEV_SYSADMIN` / `PRD_SYSADMIN` | Account Role | Possède les bases et warehouses de l'environnement |
| `DEV_RBAC` / `PRD_RBAC` | Account Role | Possède les Database/Schema Access Roles — gouvernance des accès, séparée de l'administration |
| `DEV_READER` / `PRD_READER` | Account Role | Point d'entrée lecture agrégé de l'environnement |
| `DB_R` / `DB_RW` / `DB_C` | Database Role | Agrègent les Schema Access Roles de toute la base — aucun privilège direct |
| `TEST_SCHEMA_R` / `_RW` / `_C` | Database Role | Portent les privilèges réels (SELECT, INSERT/UPDATE/DELETE, CREATE) sur le schéma `TEST_SCHEMA` |
| `DEV_ANALYST_RO`, `DEV_ANALYST_RW`, `DEV_DATA_ENGINEER` (+ PRD) | Account Role (persona) | Rôles attribués aux utilisateurs/applications réels |

## Principes appliqués

- **Jamais de privilège direct sur un rôle fonctionnel** : tout privilège passe par une Database Role (Schema Access Role), elle-même agrégée dans une Database Access Role, puis rattachée au rôle fonctionnel.
- **`MANAGED ACCESS`** activé sur `TEST_SCHEMA` : seul le propriétaire du schéma peut accorder l'accès aux objets, les créateurs d'objets ne peuvent pas contourner la gouvernance.
- **Les Database Roles ne possèdent jamais d'objets.** Le rôle `TEST_SCHEMA_C` donne le droit de `CREATE`, mais les objets créés appartiennent au rôle *compte* actif au moment de la création (ici `DEV_DATA_ENGINEER`), jamais à la Database Role.
- **Séparation administration / gouvernance** : `<ENV>_SYSADMIN` possède les objets structurels (DB, warehouse) ; `<ENV>_RBAC` possède les rôles d'accès et gère qui a droit à quoi.
- **Pas de bundling donnée/compute** : chaque persona reçoit son propre accès warehouse (`GRANT USAGE ON WAREHOUSE`), distinct de l'accès aux données.
- **Remontée vers les rôles OOB** : les rôles d'environnement sont octroyés à `SYSADMIN`/`SECURITYADMIN` pour que l'administration centrale garde une visibilité totale.
- **Grants `FUTURE`** systématiques en complément des grants `ALL`, pour que les nouveaux objets créés dans `TEST_SCHEMA` héritent automatiquement des bons droits.

## Contenu du script, section par section

| # | Section | Contenu |
|---|---|---|
| 1 | Pré-requis | Rappel des rôles d'exécution (USERADMIN crée les rôles, SYSADMIN crée les objets) |
| 2 | Rôles d'environnement | Création de `DEV_SYSADMIN/RBAC/READER` et `PRD_SYSADMIN/RBAC/READER`, remontée vers les rôles OOB |
| 3 | Warehouses | `DEV_TEST_WH` et `PRD_TEST_WH`, ownership transférée aux SYSADMIN d'environnement |
| 4 | Bases de données | `DEV_TEST_RBAC_DB` et `PRD_TEST_RBAC_DB`, ownership transférée |
| 5 | Database Access Roles | `DB_R` / `DB_RW` / `DB_C` par base, ownership transférée au rôle RBAC |
| 5bis | Délégation des privilèges structurels | `GRANT CREATE SCHEMA` et `GRANT CREATE DATABASE ROLE ON DATABASE ... TO ROLE <ENV>_RBAC` — nécessaire car `<ENV>_RBAC` ne possède pas la base (ownership = `<ENV>_SYSADMIN`), sans quoi la Section 6 échoue sur chacun de ces deux privilèges |
| 6 | Schéma + Schema Access Roles | Création de `TEST_SCHEMA` (MANAGED ACCESS) et de `TEST_SCHEMA_R/_RW/_C`, hiérarchie interne, agrégation dans les Database Access Roles |
| 7 | Rôles fonctionnels (personas) | `DEV_ANALYST_RO`, `DEV_ANALYST_RW`, `DEV_DATA_ENGINEER` (+ PRD) |
| 8 | Rattachements | Database Access Roles + warehouse accordés aux personas ; `ANALYST_RO` remonté vers `READER` |
| 9 | Attribution utilisateurs | Placeholders `GRANT ROLE ... TO USER <...>` à adapter avant exécution |
| 9bis | Rattachement SCIM | Mapping groupes IdP → rôles fonctionnels, règles de cumul de personas |
| 9ter | Auto-attribution de test | Grant temporaire des 3 personas DEV à l'utilisateur courant (`CURRENT_USER()`) pour pouvoir exécuter les Sections 10/11 sans attendre un vrai utilisateur de test — **à retirer en production**, voir Section 9/9bis |
| 10 | Jeu de données de test | Table `CUSTOMERS_TEST` créée via `DEV_DATA_ENGINEER`, peuplée de 3 lignes |
| 11 | Validation | `SHOW GRANTS` + scénarios de test commentés (lecture seule doit échouer en écriture, etc.) |
| 12 | Nettoyage (optionnel) | Bloc commenté pour supprimer entièrement le jeu de test |

## Comment utiliser le script

1. **Relire** l'intégralité du script, en particulier les sections 9 (utilisateurs) et 12 (nettoyage).
2. **Remplacer** les placeholders `<USER_...>` de la section 9 par des logins réels existants dans le compte utilisé pour le Meeting Flake du 25 novembre 2026 dans les locaux d'APICIL.
3. **Exécuter section par section**, dans l'ordre (chaque section dépend de la précédente), avec le rôle indiqué en tête de chaque bloc (`USE ROLE ...`).
4. **Valider** avec la section 11 :
   - `DEV_ANALYST_RO` doit pouvoir `SELECT` mais pas `INSERT`.
   - `DEV_ANALYST_RW` doit pouvoir `INSERT`/`UPDATE`/`DELETE` mais pas `CREATE TABLE`.
   - `DEV_DATA_ENGINEER` doit pouvoir créer des objets (DDL).
5. **Nettoyer** si besoin via la section 12 (décommenter avant exécution).

## Rattachement des rôles provisionnés par SCIM

Les rôles créés automatiquement par un provisioning SCIM (Entra ID, Okta, etc.) doivent être rattachés **aux rôles fonctionnels (personas) de la Section 7**, jamais directement aux Database Roles (`DB_R`/`DB_RW`/`DB_C`, `TEST_SCHEMA_R`/`_RW`/`_C`).

**Pourquoi** : SCIM ne peut provisionner que des grants `ROLE → USER` sur des *Account Roles*. Les Database Roles ne sont pas assignables à un utilisateur — elles ne sont grantables qu'à d'autres rôles — donc elles ne peuvent pas être un point d'attache SCIM.

| Groupe IdP (exemple) | Rôle Snowflake à mapper |
|---|---|
| `SNOW-DEV-ANALYST-RO` | `DEV_ANALYST_RO` |
| `SNOW-DEV-ANALYST-RW` | `DEV_ANALYST_RW` |
| `SNOW-DEV-DATA-ENGINEER` | `DEV_DATA_ENGINEER` |
| `SNOW-PRD-ANALYST-RO` | `PRD_ANALYST_RO` |
| `SNOW-PRD-ANALYST-RW` | `PRD_ANALYST_RW` |
| `SNOW-PRD-DATA-ENGINEER` | `PRD_DATA_ENGINEER` |

Règles à respecter (détaillées en Section 9bis du script) :

- **1 groupe IdP = 1 rôle fonctionnel** : pas de bundling de plusieurs personas dans un même groupe/rôle.
- **Jamais sur un rôle d'administration** (`<ENV>_SYSADMIN`, `<ENV>_RBAC`) sauf pour une population d'administrateurs plateforme très restreinte, documentée comme exception.
- **Jamais sur un rôle OOB** (`ACCOUNTADMIN`, `SYSADMIN`, etc.) via un rôle wrapper — si nécessaire, gérer ces attributions par script versionné, pas via SCIM.
- **Cumul de personas** (ex: un utilisateur ayant besoin de DEV et PRD, ou de plusieurs domaines) : activer les rôles secondaires (`ALTER USER ... SET DEFAULT_SECONDARY_ROLES = ('ALL')`) plutôt que de créer un rôle combiné sur mesure — voir skill `secondary-roles`.
- **Rôle par défaut** : définir `DEFAULT_ROLE` / `DEFAULT_WAREHOUSE` sur l'utilisateur pour que la persona principale soit active sans action de sa part.

## Pour aller plus loin

Ce script est volontairement limité au périmètre de test demandé (2 environnements, 1 base, 1 schéma, 3 personas). Pour étendre vers un déploiement réel, voir les sous-skills du skill `rbac` :

- `database-access-roles` / `schema-access-roles` — pour ajouter d'autres bases/schémas
- `domain-admin-roles` — si une gouvernance fédérée par domaine métier devient nécessaire
- `secondary-roles` — pour permettre à un utilisateur de cumuler plusieurs personas sans changer de rôle actif
- `policy-roles` — pour référencer correctement les rôles dans des masking policies / row access policies
- `oob-account-roles` — pour les rôles d'accès `_AR_*` (EXECUTE TASK, APPLY TAG, etc.) si le périmètre s'étend

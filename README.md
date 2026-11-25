# FLAKE #3 — Architecture de plateforme data & RBAC Snowflake

Supports, documentation et code de deux interventions présentées lors du **Snowflake User Group Lyon · FLAKE #3**, le **25 novembre 2026**, dans les locaux d'APICIL.

| Intervention | Intervenant | Thème |
|---|---|---|
| Quel modèle pour votre plateforme data ? | Frédéric Adet | Architecture, modélisation et organisation d'une plateforme data |
| Comprendre le RBAC Snowflake | Pierre-Mickaël Chancrin | Rôles, hiérarchie, bonnes pratiques et automatisation |

## Contenu du dépôt

```
.
├── presentations/
│   ├── plateformes-data/      # Quel modèle pour votre plateforme data ?
│   │   ├── Fred_FLAKE_Modeles_de_plateformes_data.html
│   │   ├── Fred_FLAKE_Modeles_de_plateformes_data.pptx
│   │   └── Fred_FLAKE_Modeles_de_plateformes_data.pdf
│   └── rbac/                  # Comprendre le RBAC Snowflake
│       ├── PierMick_FLAKE_Comprendre_le_RBAC_Snowflake.html
│       ├── PierMick_FLAKE_Comprendre_le_RBAC_Snowflake.pptx
│       └── PierMick_FLAKE_Comprendre_le_RBAC_Snowflake.pdf
└── rbac-setup/                # Code et documentation du jeu de test RBAC
    ├── 261125-RBAC-setup-for-flake-meeting.sql
    └── README.md
```

Chaque présentation est fournie en trois formats : **HTML** (diaporama autonome, navigation au clavier, touche `N` pour les notes), **PPTX** (éditable) et **PDF** (lecture et partage).

## 1. Quel modèle pour votre plateforme data ?

Trois niveaux de décision, à ne pas confondre :

- **Architecture** : où et dans quel ordre la donnée est-elle transformée ? Lakehouse et Medallion (Bronze / Silver / Gold), avec dbt et Snowflake (Snowpipe, Openflow, Iceberg, Dynamic Tables).
- **Modélisation** : comment structurer la donnée dans chaque couche ? Inmon, Kimball, Data Vault (AutomateDV, datavault4dbt).
- **Organisation** : qui possède, produit et publie la donnée ? Data Mesh, dbt Mesh, produits de données, couche sémantique (Semantic Views, MetricFlow).

Message clé : commencer simple avec Medallion + Kimball, ajouter du Data Vault quand l'historisation et l'audit l'exigent, passer au Mesh quand l'organisation est prête.

Supports : [`presentations/plateformes-data/`](./presentations/plateformes-data/)

## 2. Comprendre le RBAC Snowflake

Présentation de 14 diapositives et jeu de test complet, qui illustre un pattern **compte unique avec séparation logique des environnements** (DEV / PRD) :

- rôles natifs (`ACCOUNTADMIN`, `SYSADMIN`, `SECURITYADMIN`, `USERADMIN`) ;
- rôles d'administration d'environnement (`<ENV>_SYSADMIN`, `<ENV>_RBAC`, `<ENV>_READER`) ;
- Database Access Roles (`DB_R` / `DB_RW` / `DB_C`) et Schema Access Roles (`<schema>_R` / `_RW` / `_C`), sous forme de Database Roles ;
- rôles fonctionnels (personas) `ANALYST_RO`, `ANALYST_RW`, `DATA_ENGINEER`, point d'attache des utilisateurs et du provisioning SCIM ;
- `MANAGED ACCESS`, grants `FUTURE`, accès warehouse distinct de l'accès aux données.

Supports : [`presentations/rbac/`](./presentations/rbac/)

### Jeu de test RBAC (`rbac-setup/`)

Le script [`261125-RBAC-setup-for-flake-meeting.sql`](./rbac-setup/261125-RBAC-setup-for-flake-meeting.sql) déploie la hiérarchie sur deux environnements fictifs (`DEV_TEST_RBAC_DB`, `PRD_TEST_RBAC_DB`, schéma `TEST_SCHEMA`), crée un jeu de données et propose des scénarios de validation ainsi qu'un nettoyage complet. Le détail section par section est dans [`rbac-setup/README.md`](./rbac-setup/README.md).

> ⚠️ **Le script n'a pas été exécuté.** Relisez-le intégralement et remplacez les placeholders (`<USER_...>`, section 9) avant tout lancement. La section 9ter s'auto-attribue temporairement les personas DEV : à retirer en production.

Ordre d'exécution : sections 0 à 11 dans l'ordre, chacune avec le rôle indiqué en tête de bloc (`USE ROLE ...`) ; section 12 (nettoyage) à décommenter uniquement pour tout supprimer.

## Prérequis

- Un compte Snowflake avec accès à `ACCOUNTADMIN` ou aux rôles `SYSADMIN`, `SECURITYADMIN` et `USERADMIN`, de préférence un compte de test dédié.
- Pour lire les présentations : un navigateur (HTML), PowerPoint ou équivalent (PPTX), ou n'importe quel lecteur PDF. Le HTML charge la police Montserrat depuis Google Fonts.

## Auteurs

- **Frédéric Adet** : modèles de plateformes data
- **Pierre-Mickaël Chancrin** : RBAC Snowflake
- Organisé par le **Snowflake User Group Lyon**

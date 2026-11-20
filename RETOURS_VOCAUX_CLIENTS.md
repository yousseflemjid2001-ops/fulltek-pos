# Retours Vocaux Clients — Full·Tek POS

Ce document centralise les notes vocales clients et les exigences métier associées.

---

## Vocal #1 — Architecture Compte Master, Profils RBAC granulaires & Utilisateurs
**Date :** 2026-11-20  

### Transcription fidèle
> Je viens de résoudre le problème avec le client. Normalement, quand on crée un client ou un compte pour la première fois, il y a un compte master et on définit les profils : caissier, superviseur, etc. Le profil dépend du client. Certains clients donnent au caissier l'accès pour imprimer le Z, et d'autres non. Il y a des clients qui ont un caissier qui est à la fois caissier et superviseur, et un autre caissier qui n'est pas superviseur. C'est pour ça que je t'ai dit qu'avant, il fallait que les droits d'accès soient par option. Par exemple, pour le profil caissier, on lui donne l'ouverture de table, servir table, nombre de couverts, ouverture de caisse, etc. Au superviseur, on lui donne les statistiques, plus les options de caissier, et l'administrateur a tout. L'architecture est comme ça. Ensuite, on passe aux utilisateurs. Chaque utilisateur, on lui crée un mot de passe et son badge magnétique, et après on lui attribue le profil. C'est l'architecture des produits que je connais. Il y a un autre profil, serveur. Le serveur, il reçoit les commandes des tables et passe les commandes parfois par tablette et parfois il va en caisse pour passer la commande avec le caissier. C'est un autre profil, il n'a pas beaucoup d'accès.

### Exigences extraites
1. **Compte Master initial (Administrateur client)** :
   - Lors de la création d'un nouveau compte client, un **compte Master** est créé avec tous les droits.
   - Depuis ce compte Master, le client configure ses **profils (rôles)** puis ses **utilisateurs**.
2. **Droits d'accès granulaires par option (Profils personnalisables)** :
   - Les permissions ne doivent pas être figées globalement, mais configurables **option par option** selon chaque client :
     - *Exemples d'options :* ouverture de table, servir table, nombre de couverts, ouverture de caisse, encaissement, impression du Z de caisse, statistiques, annulation/remise, etc.
   - Deux caissiers d'un même établissement peuvent avoir des profils différents (ex. un *Caissier simple* sans impression Z vs un *Caissier-Superviseur* avec impression Z et stats).
   - **Profil Administrateur** : accès total à toutes les options.
   - **Profil Superviseur** : options caissier + statistiques (selon configuration client).
   - **Profil Serveur** : accès restreint (prise de commande sur table via tablette ou passage en caisse avec le caissier ; peu d'accès sensibles).
3. **Gestion des Utilisateurs** :
   - Création de chaque utilisateur avec :
     - **Mot de passe / PIN**
     - **Badge magnétique** (identifiant / lecture badge RFID/MSR)
     - **Attribution d'un profil** défini précédemment.

														/*FRENCH VERSION */
/*************************************************************************************************************************************************/
/*                                           ANALYSE DES DONNÉES CLASSICMODELS                                            */
/*************************************************************************************************************************************************/

USE classicmodels;

/************************************************************************************************************************/
									/* PARTIE 1: ANALYSE ET CREATIONS PRIMAIRE */
/**************************************************************************************************************************/

/*Nombres totale de clients, d'employées et des commandes*/

SELECT 
	(select count(distinct customerNumber )from classicmodels.customers) as total_clients,
    (select count(distinct employeeNumber) from classicmodels.employees )as total_employées,
    (select count( distinct orderNumber) from classicmodels.orders) as nombre_total_commandes;
    
/*Creation d'une table de jointure entre la table client et des commandes
 afin de pouvoir connaitre quels sont les clients qui ont commandé par pays */

DROP TABLE IF exists consommateur_commandes;
CREATE TABLE consommateur_commandes AS
SELECT
    conso.customerNumber AS conso_customerNumber, 
    conso.customerName,
    conso.contactLastName,
    conso.contactFirstName,
    conso.phone,
    conso.addressLine1,
    conso.addressLine2,
    conso.city,
    conso.state,
    conso.postalCode,
    conso.country,
    commandes.*
/* jointure de la table des consommateurs avec la table des commandes */
FROM classicmodels.customers AS conso
INNER JOIN classicmodels.orders AS commandes
ON conso.customerNumber = commandes.customerNumber; /* regrouper par consommateur */

/*Affichage des différents types de status */
SELECT 
status
FROM classicmodels.consommateur_commandes
group by status;


/*1.4) Réalisation et ajout du chiffre d'affaire avec le tableau des détails des commandes */
ALTER TABLE classicmodels.orderdetails
ADD COLUMN chiffre_d_affaire INT AS (quantityOrdered * priceEach);


/************************************************************************************************************************/
      /* PERTIE 2 :  ANALYSE DES PRODUITS PHARES : Produits les plus vendus et générant le plus de chiffre d'affaires */
/**************************************************************************************************************************/
 drop tables best_cli2003, best_cli2004,best_cli2005, best_country;
 

/*Produits les plus vendus globalement*/
SELECT p.productCode, p.productName, SUM(quantityOrdered) AS total_vendu
FROM orderdetails as detcom
JOIN products as p on detcom.productCode = p.productCode
GROUP BY productCode, productName
ORDER BY total_vendu DESC
LIMIT 10;

/*Produits générant le plus de chiffre d'affaires*/
SELECT p.productCode, p.productName, SUM(detcom.quantityOrdered * detcom.priceEach) AS chiffre_affaires
FROM orderdetails as detcom
JOIN products as p on p.productCode=detcom.productCode
GROUP BY productCode, productName
ORDER BY chiffre_affaires DESC
LIMIT 10;

/******************************************************************************************************************************/
             /* PARTIE 3 ANALYSE DES PERFORMANCES CLIENTS : Identification des clients les plus rentables */
/******************************************************************************************************************************/



/*NOMBRES DE CLIENTS par années*/
drop table if exists nb_cli;
create table nb_cli
select
	(Select
	count(distinct customerNumber) 
from classicmodels.consommateur_commandes
where requiredDate between '2003-01-01' and '2003-12-31')as nb_client_2003,
	(Select
	count(distinct customerNumber) 
from classicmodels.consommateur_commandes
where requiredDate between '2004-01-01' and '2004-12-31')as nb_client_2004,
	(Select
	count(distinct customerNumber) 
from classicmodels.consommateur_commandes
where requiredDate between '2005-01-01' and '2005-12-31') as nb_client_2005
;




/* taux de variation du nombre de client par années */
SELECT 
    t1.nb_client_2003 AS annee_2003, 
    t2.nb_client_2004 AS annee_2004,
    t3.nb_client_2005 as annees_2005,
    ROUND(((t2.nb_client_2004 - t1.nb_client_2003) / t1.nb_client_2003) * 100, 2) AS taux_de_variation2003to2004,
    ROUND(((t3.nb_client_2005- t2.nb_client_2004) / t2.nb_client_2004) * 100, 2) AS taux_de_variation2004to2005
FROM 
    classicmodels.nb_cli as t1
INNER JOIN 
    classicmodels.nb_cli as t2
INNER JOIN 
    classicmodels.nb_cli as t3;

/*On remarque un déclin de clients de par années*/

/*  Quels sont les meilleurs clients par pays et par année (de 2003 à 2005) ? */

SELECT 
    cc.customerName AS nom_client,
    cc.customerNumber,
    cc.country AS pays,
    YEAR(cc.orderDate) AS annee,
    SUM(detailscom.quantityOrdered * detailscom.priceEach) AS chiffre_d_affaire_total
FROM 
    classicmodels.consommateur_commandes AS cc
INNER JOIN 
    classicmodels.orderdetails AS detailscom 
    ON cc.orderNumber = detailscom.orderNumber
WHERE 
    cc.orderDate BETWEEN '2003-01-01' AND '2005-12-31' 
    AND cc.status IN ('Shipped','In Process','Resolved','On Hold') /*je n'ai pas pris les commandes 'canceled' ou 'disputed' 
    car ils ne rapportent aucun Chiffre d'affaire a l'entreprise selon moi */
GROUP BY 
    cc.customerName, cc.customerNumber, cc.country, YEAR(cc.orderDate)
ORDER BY 
    cc.country ASC, annee ASC, chiffre_d_affaire_total DESC;

/* Classement des clients par chiffre d'affaires total*/
SELECT customerNumber, customerName, country, SUM(quantityOrdered * priceEach) AS total_revenu
FROM customers
JOIN orders USING (customerNumber)
JOIN orderdetails USING (orderNumber)
GROUP BY customerNumber, customerName, country
ORDER BY total_revenu DESC
LIMIT 10;


/*Fidélité des clients (nombre moyen de commandes par client)*/
SELECT customerNumber, customerName, COUNT(orderNumber) AS nombre_commandes
FROM classicmodels.consommateur_commandes 
GROUP BY customerNumber, customerName
ORDER BY nombre_commandes DESC
LIMIT 10;



/* Création et classification d'une table avec la quantité totale de produits pour chaque année */
drop table if exists classicmodels.total_quantitees_produit_commandes2003to2005;
create table classicmodels.total_quantitees_produit_commandes2003to2005 as 
SELECT
    '2003' AS Annees,
    c.country AS pays,
    p.productCode AS num_produit,
    p.productName AS nom_produit,
    SUM(od.quantityOrdered) AS total_quantites_commander
FROM 
    classicmodels.orderdetails AS od
INNER JOIN 
    classicmodels.products AS p 
    ON od.productCode = p.productCode
INNER JOIN 
    classicmodels.orders AS commandes
    ON od.orderNumber = commandes.orderNumber
INNER JOIN 
    classicmodels.customers AS c
    ON commandes.customerNumber = c.customerNumber
WHERE 
    YEAR(commandes.orderDate) = 2003
GROUP BY 
    c.country, p.productCode, p.productName

UNION ALL

SELECT
    '2004' AS Annees,
    c.country AS pays,
    p.productCode AS num_produit,
    p.productName AS nom_produit,
    SUM(od.quantityOrdered) AS total_quantites_commander
FROM 
    classicmodels.orderdetails AS od
INNER JOIN 
    classicmodels.products AS p 
    ON od.productCode = p.productCode
INNER JOIN 
    classicmodels.orders AS commandes
    ON od.orderNumber = commandes.orderNumber
INNER JOIN 
    classicmodels.customers AS c
    ON commandes.customerNumber = c.customerNumber
WHERE 
    YEAR(commandes.orderDate) = 2004
GROUP BY 
    c.country, p.productCode, p.productName

UNION ALL

SELECT
    '2005' AS Annees,
    c.country AS pays,
    p.productCode AS num_produit,
    p.productName AS nom_produit,
    SUM(od.quantityOrdered) AS total_quantites_commander
FROM 
    classicmodels.orderdetails AS od
INNER JOIN 
    classicmodels.products AS p 
    ON od.productCode = p.productCode
INNER JOIN 
    classicmodels.orders AS commandes
    ON od.orderNumber = commandes.orderNumber
INNER JOIN 
    classicmodels.customers AS c
    ON commandes.customerNumber = c.customerNumber
WHERE 
    YEAR(commandes.orderDate) = 2005
GROUP BY 
    c.country, p.productCode, p.productName

ORDER BY 
    Annees ASC, total_quantites_commander DESC;

 /* Affichage du nombre de quantité vendus par pays et par années */
select 
	Annees,
    pays,
	sum(total_quantites_commander) as Total_qte_vendus
from classicmodels.total_quantitees_produit_commandes2003to2005
group by pays, Annees
;

/*Comme attendus, sur chaque années les USA sont en tête */





/************************************************************************************************************************/
		      /* PARTIE 4 ANALYSE DES TENDANCES ANNUELLES ET SAISONNIÈRES : Identifier les pics de vente*/
/**************************************************************************************************************************/


/*Chiffre d'affaires par année*/
drop table ca_annee ;
create table ca_annee as 
SELECT YEAR(orderDate) AS annee, SUM(quantityOrdered * priceEach) AS chiffre_affaires_annuel
FROM orders as o 
JOIN orderdetails as detcom on detcom.orderNumber= o.orderNumber
GROUP BY annee
ORDER BY annee;

/*  Taux de variation du chiffre d'affaire annuel obtenue entre 2003 et 2004 puis entre 2004 et 2005*/

SELECT 
    t1.annee AS année_finale, 
    t2.annee AS année_initiale,
    t1.chiffre_affaires_annuel AS total_commandes_finale,
    t2.chiffre_affaires_annuel AS total_commandes_initiale,
    ROUND(((t1.chiffre_affaires_annuel - t2.chiffre_affaires_annuel) / t2.chiffre_affaires_annuel) * 100, 2) AS taux_de_variation
FROM 
    classicmodels.ca_annee  as t1
INNER JOIN 
    classicmodels.ca_annee   as t2
ON 
    t1.annee = t2.annee + 1
ORDER BY 
    t1.annee;


/*Moyenne des ventes par mois pour déceler la saisonnalité*/
SELECT YEAR(o.orderDate) AS annee, MONTH(o.orderDate) AS mois, SUM(detcom.quantityOrdered * detcom.priceEach) AS chiffre_affaires_mensuel
FROM classicmodels.orders as o
JOIN orderdetails as detcom on  detcom.orderNumber=o.orderNumber
GROUP BY annee, mois
ORDER BY annee, mois;

/* En 2003, on peut observer des pics en Avril , juillet, et en novembre et des creux en Décembre, Janvier, juin et en Aout.
En 2004, on observe des creux en Avril, Septembre et des pics en Janvier, Juin, Aout, Novembre.
Enfin en 2005, on observe des creux en fevrier et  en mai */



/* Evaluons les pertes dans les commandes annulées ou contestées*/
drop view if exists perteca3;
create view perteca3 as
SELECT 
    cc.customerName AS nom_client,
    cc.customerNumber,
    cc.country AS pays,
    ('2003') AS annee,
    SUM(detailscom.quantityOrdered * detailscom.priceEach) AS chiffre_d_affaire_total
   
FROM 
    classicmodels.consommateur_commandes AS cc
INNER JOIN 
    classicmodels.orderdetails AS detailscom 
    ON cc.orderNumber = detailscom.orderNumber
WHERE 
    cc.orderDate BETWEEN '2003-01-01' AND '2003-12-31' 
    AND cc.status IN ('Cancelled','Disputed') 
    GROUP BY 
    cc.customerName, cc.customerNumber, cc.country, annee
ORDER BY 
    cc.country ASC, annee ASC, chiffre_d_affaire_total DESC;


/*meme chose en 2004*/
drop view if exists perteca4; 
create view perteca4 as
SELECT 
    cc.customerName AS nom_client,
    cc.customerNumber,
    cc.country AS pays,
    ('2004') AS annee,
    SUM(detailscom.quantityOrdered * detailscom.priceEach) AS chiffre_d_affaire_total
   
FROM 
    classicmodels.consommateur_commandes AS cc
INNER JOIN 
    classicmodels.orderdetails AS detailscom 
    ON cc.orderNumber = detailscom.orderNumber
WHERE 
    cc.orderDate BETWEEN '2004-01-01' AND '2004-12-31' 
    AND cc.status IN ('Cancelled','Disputed') 
GROUP BY 
    cc.customerName, cc.customerNumber, cc.country, annee
ORDER BY 
    cc.country ASC, annee ASC, chiffre_d_affaire_total DESC;

/*Meme chose en 2005*/
drop view if exists perteca5; 
create view perteca5 as
SELECT 
    cc.customerName AS nom_client,
    cc.customerNumber,
    cc.country AS pays,
    ('2005') AS annee,
    SUM(detailscom.quantityOrdered * detailscom.priceEach) AS chiffre_d_affaire_total
   
FROM 
    classicmodels.consommateur_commandes AS cc
INNER JOIN 
    classicmodels.orderdetails AS detailscom 
    ON cc.orderNumber = detailscom.orderNumber
WHERE 
    cc.orderDate BETWEEN '2005-01-01' AND '2005-12-31' 
    AND cc.status IN ('Cancelled','Disputed') 
GROUP BY 
    cc.customerName, cc.customerNumber, cc.country, annee
ORDER BY 
    cc.country ASC, annee ASC, chiffre_d_affaire_total DESC;

/*Calulons la perte global par année */
drop view if exists pertes ;
create view pertes_commandes as
select
('2003') as Années,
sum(chiffre_d_affaire_total) as perte_glo_commandes
from perteca3
union
select
('2004') as Années,
sum(chiffre_d_affaire_total) as perte_glo_commandes
from perteca4
union
select
('2005') as Années,
sum(chiffre_d_affaire_total) as perte_glo_commandes
from perteca5;



/* Taux de variation nombre de commande totale entre 2003 et 2004 puis entre 2004 et 2005*/
drop table if exists pertes_CA;
create table pertes_CA as 
SELECT 
    t1.Années AS année_finale, 
    t2.Années AS année_initiale,
    t1.perte_glo_commandes AS total_perteca_finale,
    t2.perte_glo_commandes AS total_perteca_initiale,
    ROUND((( t1.perte_glo_commandes - t2.perte_glo_commandes) / t2.perte_glo_commandes) * 100, 2) AS taux_de_variation
FROM 
    classicmodels.pertes_commandes as t1
INNER JOIN 
    classicmodels.pertes_commandes  as t2
ON 
    t1.Années = t2.Années+1
ORDER BY 
    t1.Années;

/*On peut remarquer que classicmodels a perdu pas mal parmis les commandes annulés ou contestés 
de la par des clients durant la période de 2003 à 2004 ( 155.80% de taux de variation de perte en chiffre d'affaire potentiel),
 mais il a quand meme su rebondir un peu durant la période qui a suivit (-64.39% de taux de variation durant le période de 2004 à 2005) */




/************************************************************************************************************************/
	       /* PARTIE 5 ANALYSE DES ZONES GÉOGRAPHIQUES : Pays et régions les plus performants */
/**************************************************************************************************************************/


/*Nombre de pays par années en 2003*/

select
	('2003') as Annees,
	count(distinct pays ) as nb_pays
from classicmodels.total_quantitees_produit_commandes2003to2005
Where Annees = '2003'
union
/*Nombre de pays par années en 2004*/
select
	('2004') as Annees,
	count(distinct pays ) as nb_pays
from classicmodels.total_quantitees_produit_commandes2003to2005
Where Annees = '2004'
union
select
	('2005') as Annees,
	count(distinct pays ) as nb_pays
from classicmodels.total_quantitees_produit_commandes2003to2005
Where Annees = '2005';

/* Chiffre d'affaires total par pays*/

SELECT c.country, SUM(quantityOrdered * priceEach) AS total_revenu
FROM customers as c
JOIN orders  as o  on o.customerNumber= c.customerNumber
JOIN orderdetails as detcom on detcom.orderNumber = o.orderNumber
GROUP BY country
ORDER BY total_revenu DESC;





/************************************************************************************************************************/
    /* PARTIE 6 ANALYSE DES PERFORMANCES DES CATÉGORIES DE PRODUITS : Identifier les catégories les plus rentables */
/**************************************************************************************************************************/


/* Quels sont les meilleurs produits et le meilleurs pays par années ( top 10)*/

/* EN 2003*/
select* from classicmodels.total_quantitees_produit_commandes2003to2005
where Annees= 2003  limit 10; /*USA en tete */

/*EN 2004*/
select* from classicmodels.total_quantitees_produit_commandes2003to2005
where Annees= 2004 limit 10; /*toujours les USA en tete = focalisation USA */

/*EN 2005*/
select* from classicmodels.total_quantitees_produit_commandes2003to2005
where Annees= 2005  limit 10;
/* On peut remarquer qu'au travers de ces tableaux que les voitures sont les produits qui vendant le plus ( surtout aux USA et en Espagne */

/*Chiffre d'affaires par catégorie de produits*/
SELECT p.productLine, SUM(detcom.quantityOrdered * detcom.priceEach) AS chiffre_affaires_categorie
FROM classicmodels.products as p
JOIN orderdetails as detcom on detcom.productCode=p.productCode
GROUP BY productLine
ORDER BY chiffre_affaires_categorie DESC;

/*On constate que parmis tous les produits que classicmodels propose, les productions de trains, de bateaux et d'avions semblent lui retourner moins de chiffre d'affaire.
(Cela s'explique surement en raison du fait que ce produit soit destinée à une brache plus restrainte de clients  ( hommes fortunées, une entreprise ou à un gouvernement)). 
A la différence de celui-ci, la vente de voitures ( tant en gamme classique qu'en gamme vintage ) et de motos représentent la plus grande part de son chiffre d'affaire.
( sans doute par le fait qu'il soit plus accéssible pour des clients lamda).
Autrement dit, on observe que géréralement, classic models s'est plus centré sur la vente de produits accéssible a tous que des produits destinées à des hommes fortunées, une entreprise ou à un gouvernement. */




/************************************************************************************************************************/
				   /* PARTIE 7:  ANALYSE DES COMMANDES : Suivi des commandes et annulations*/
/**************************************************************************************************************************/

/* Affichage du nombre de clients qui ont commandés en 2003*/

drop table if exists classicmodels.nb_cli_commande2003to2005;
create table classicmodels.nb_cli_commande2003to2005 AS
SELECT 
(select count(status) 
FROM classicmodels.consommateur_commandes
where status= 'Shipped' and requiredDate between '2003-01-01' and '2003-12-31')as total_expédiés,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'In Process' and requiredDate between '2003-01-01' and '2003-12-31')as total_en_cours_expedition,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Cancelled' and requiredDate between '2003-01-01' and '2003-12-31')as total_annulees,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Resolved' and requiredDate between '2003-01-01' and '2003-12-31')as total_résolus,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Disputed' and requiredDate between '2003-01-01' and '2003-12-31')as total_conteste,
(select count(status)
from classicmodels.consommateur_commandes
where status= 'On Hold'and requiredDate between '2003-01-01' and '2003-12-31') as total_en_attentes,
(select count(status)
from classicmodels.consommateur_commandes 
where requiredDate between '2003-01-01' and '2003-12-31') as total_commandes, 
('2003') as Années
union
/*  Affichage du nombre de clients qui ont commandés en 2004*/
SELECT 
(select count(status) 
FROM classicmodels.consommateur_commandes
where status= 'Shipped' and requiredDate between '2004-01-01' and '2004-12-31')as total_expédiés,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'In Process' and requiredDate between '2004-01-01' and '2004-12-31')as total_en_cours_expedition,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Cancelled' and requiredDate between '2004-01-01' and '2004-12-31')as total_annulees,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Resolved' and requiredDate between '2004-01-01' and '2004-12-31')as total_résolus,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Disputed' and requiredDate between '2004-01-01' and '2004-12-31')as total_conteste,
(select count(status)
from classicmodels.consommateur_commandes
where status= 'On Hold'and requiredDate between '2004-01-01' and '2004-12-31') as total_en_attentes,
(select count(status)
from classicmodels.consommateur_commandes
where requiredDate between '2004-01-01' and '2004-12-31' ) as total_commandes,
('2004') as Années

union
/*  Affichage du nombre de clients qui ont commandés en 2005*/

SELECT 
 
(select count(status) 
FROM classicmodels.consommateur_commandes
where status= 'Shipped' and requiredDate between '2005-01-01' and '2005-12-31')as total_expédiés,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'In Process' and requiredDate between '2005-01-01' and '2005-12-31')as total_en_cours_expedition,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Cancelled' and requiredDate between '2005-01-01' and '2005-12-31')as total_annulees,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Resolved' and requiredDate between '2005-01-01' and '2005-12-31')as total_résolus,
(select count(status) 
from classicmodels.consommateur_commandes
where status= 'Disputed' and requiredDate between '2005-01-01' and '2005-12-31')as total_conteste,
(select count(status)
from classicmodels.consommateur_commandes
where status= 'On Hold'and requiredDate between '2005-01-01' and '2005-12-31') as total_en_attentes,
(select count(status)
from classicmodels.consommateur_commandes
where requiredDate between '2005-01-01' and '2005-12-31' ) as total_commande,
('2005') as Années;

/*    Taux de variation nombre de commande totale entre 2003 et 2004 puis entre 2004 et 2005*/
SELECT 
    t1.Années AS année_finale, 
    t2.Années AS année_initiale,
    t1.total_commandes AS total_commandes_finale,
    t2.total_commandes AS total_commandes_initiale,
    ROUND(((t1.total_commandes - t2.total_commandes) / t2.total_commandes) * 100, 2) AS taux_de_variation
FROM 
    classicmodels.nb_cli_commande2003to2005 as t1
INNER JOIN 
    classicmodels.nb_cli_commande2003to2005  as t2
ON 
    t1.Années = t2.Années + 1
ORDER BY 
    t1.Années;
    
    
    
    

/*CALCULONS LE MEILLEUR  EMPLOYEES*/

/* 1. Classement des employés par nombre total de commandes gérées */
SELECT 
    e.employeeNumber AS num_employe,
    e.firstName,e.lastName,
    COUNT(DISTINCT o.orderNumber) AS nombre_commandes_traitees
FROM 
    classicmodels.employees AS e
INNER JOIN 
    classicmodels.customers AS c 
    ON e.employeeNumber = c.salesRepEmployeeNumber
INNER JOIN 
    classicmodels.orders AS o 
    ON c.customerNumber = o.customerNumber
GROUP BY 
    e.employeeNumber, e.firstName, e.lastName
ORDER BY 
    nombre_commandes_traitees DESC
LIMIT 10;

/* 2. Classement des employés par chiffre d'affaires généré */
create table best_emp_ca as 
SELECT 
	e.officeCode,
    e.employeeNumber AS num_employe,
    e.firstName,e.lastName,

    SUM(od.quantityOrdered * od.priceEach) AS chiffre_d_affaires_total
FROM 
    classicmodels.employees AS e
INNER JOIN 
    classicmodels.customers AS c 
    ON e.employeeNumber = c.salesRepEmployeeNumber
INNER JOIN 
    classicmodels.orders AS o 
    ON c.customerNumber = o.customerNumber
INNER JOIN 
    classicmodels.orderdetails AS od 
    ON o.orderNumber = od.orderNumber
GROUP BY 
    e.employeeNumber, e.firstName, e.lastName
ORDER BY 
    chiffre_d_affaires_total DESC
LIMIT 10;

/* 3. Classement des employés par nombre de clients gérés */
SELECT 
    e.employeeNumber AS num_employe,
    e.firstName,e.lastName,
    COUNT(DISTINCT c.customerNumber) AS nombre_clients_gérés
FROM 
    classicmodels.employees AS e
INNER JOIN 
    classicmodels.customers AS c 
    ON e.employeeNumber = c.salesRepEmployeeNumber
GROUP BY 
    e.employeeNumber, e.firstName, e.lastName
ORDER BY 
    nombre_clients_gérés DESC
LIMIT 10;

/*Localisayion emp par pays*/
SELECT
o.country as pays,
b.*
FROM classicmodels.best_emp_ca as b
join offices as o on b.officeCode= o.officeCode;




/*On peut remarque que Hermandeez est l'employé le plus performant tant au niveau de ca rapportée, qu'au niveau de commandes géré*/

/* BILAN DES REACOMMANDATIONS :
- Classicmodels pourrait se concentrer sur les produits phares en faisant de la pub.
- Pour palier a la baisse de client , Classic models pourrait  mettre en place des programmes de fidélisation pour attirer et findéliser les clients .
- En fonction de la période, classicmodels pourrait ajuster ses stocks.
- Il pourrait aussi eventuellement voir pour quel raison certains de ses produits qui lui génrere moins de CA , tandis que d'autres lui en génére énormément et par extansion, 
il pourrait aussi essayer de reproduire la meme methode pour ses produits qui fonctionne le moins ( en prenant en compte la culture de ses clients ).  
- Il pourrait aussi eventuellement permettre a l'employé hermandez de manter en échelon poutr qu'il puisse amener des bonnes stratégie commerciales
*/

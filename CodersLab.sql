USE financial2_101;

# Structure of financial database
# Get familiar with the schema of the database and answer the following questions:
#
# What are the primary keys in the individual tables?

#The primary keys in the individual tables are: loan - loan_id, order - order_id, trans - trans_id, card - card_id,
#disp - disp_id, district - district_id, loan - loan_id, order - order_id, trans - trans_id

# What relationships do particular pairs of tables have?
-- checking type of relationship
SELECT
    account_id,
    count(trans_id) as amount #counting the number of transactions each account has performed
FROM trans #using the trans table in the database
GROUP BY account_id
ORDER BY 2 DESC; #put the highest number of transactions first

# History of granted loans (resulting csv Loans_by_period)
# Write a query that prepares a summary of the granted loans in the following dimensions:
#
# year, quarter, month,
# year, quarter,
# year,
# total.
# Display the following information as the result of the summary:
#
# total amount of loans,
# average loan amount,
# total number of given loans.

SELECT
    extract(YEAR from date) as loan_year, #getting the year from the date column
    extract(MONTH from date) as loan_month,
    extract(QUARTER from date) as loan_quarter,
    sum(amount) as total_loans, #calculating the total sum of the loans
    avg(amount) as average_loan, #calculating the average loan for the given period
    count(loan_id) as num_of_loans #counting the number of loans given in a particular period
FROM financial2_101.loan
GROUP BY 1, 2, 3 WITH ROLLUP
ORDER BY 1, 2, 3 DESC; #Ordering the results by year, month and quarter

# Loan status (results in csv Status_of_(un)paid_loans)
# On the database site, we can find information that there are a total of 682 granted loans in the database,
# of which 606 have been repaid and 76 have not.
#
# Let's assume that we don't have information about which status corresponds
# to a repaid loan and which does not. In this situation, we need to infer this information from the data.
#
# To do this, write a query to help you answer the question of which statuses
# represent repaid loans and which represent unpaid loans.
SELECT
    status,
    COUNT(status) AS count,
    SUM(COUNT(*)) OVER (ORDER BY COUNT(*) DESC) AS cumulative_sum
FROM loan
GROUP BY status
ORDER BY count DESC;
# Answer: loans with the status A and C have been repaid (there's 606 of them), while loans B and D have not.

# Analysis of accounts
# Write a query that ranks accounts according to the following criteria:
#
# number of given loans (decreasing),
# amount of given loans (decreasing),
# average loan amount,
# Only fully paid loans are considered.

SELECT account_id,
       SUM(amount) AS total_amount,
       COUNT(amount) AS loan_count,
       AVG(amount) AS avg_amount
FROM loan
WHERE status IN ('A', 'C') -- Taking only the paid loans into account
GROUP BY account_id
ORDER BY loan_count DESC;

# Fully paid loans (csv Fully_paid_loans)
# Find out the balance of repaid loans, divided by client gender.

SELECT gender, SUM(amount) as repaid_loans
FROM loan
JOIN financial2_101.disp d ON loan.account_id = d.account_id
JOIN financial2_101.client c ON c.client_id = d.client_id
WHERE status IN ('A', 'C')
GROUP BY gender;

# Client analysis - part 1 (resulting csv Client_analysis_1)
# Modifying the queries from the exercise on repaid loans, answer the following questions:
#
# Who has more repaid loans - women or men? Answer: men
# What is the average age of the borrower divided by gender? Answer: 66.83 years for men and 66.10 years for women

SELECT gender,
       SUM(amount) AS repaid_loans,
       ROUND(AVG(TIMESTAMPDIFF(YEAR, c.birth_date, CURDATE())), 2) AS average_age
FROM loan
JOIN financial2_101.disp d ON loan.account_id = d.account_id
JOIN financial2_101.client c ON c.client_id = d.client_id
WHERE status IN ('A', 'C')
GROUP BY gender
ORDER BY 2 DESC;


# Client analysis - part 2 (resulting csv Client_analysis_2)
# Make analyses that answer the questions:
#
# which area has the most clients, #Answer: Hl. m. Praha (Prague, the capital city) to all questions
# in which area the highest number of loans was paid,
# in which area the highest amount of loans was paid.
# Select only owners of accounts as clients.

SELECT d.district_id,
       d.A2,
       COUNT(client.client_id) AS num_of_clients,
       COUNT(l.loan_id) AS num_of_loans,
       SUM(l.amount) AS loans_amount
FROM financial2_101.client
JOIN financial2_101.district d ON d.district_id = client.district_id
JOIN financial2_101.disp d2 ON client.client_id = d2.client_id
JOIN financial2_101.account a ON a.account_id = d2.account_id
JOIN financial2_101.loan l ON a.account_id = l.account_id
WHERE d2.type = 'OWNER'
  AND l.status IN ('A', 'C')
GROUP BY d.district_id, d.A2;

#
# Client selection
# Check the database for the clients who meet the following results:
#
# their account balance is above 1000,
# they have more than five loans,
# they were born after 1990.
# And we assume that the account balance is loan amount - payments.
# Answer: the result is an empty table

SELECT l.account_id,
       (l.amount - l.payments) AS balance,
       EXTRACT(YEAR FROM client.birth_date) AS birth_year
FROM financial2_101.client
JOIN financial2_101.disp d ON client.client_id = d.client_id
JOIN financial2_101.loan l ON l.account_id = d.account_id
WHERE (l.amount - l.payments) > 1000
      AND l.loan_id > 5
      AND EXTRACT(YEAR FROM client.birth_date) > 1990
      ;

# Selection part 2
# From the previous exercise you probably already know that there are no customers
# who meet the requirements. Make an analysis to determine which condition caused the empty results.

SELECT l.account_id,
       (l.amount - l.payments) AS balance,
       EXTRACT(YEAR FROM client.birth_date) AS birth_year
FROM financial2_101.client
JOIN financial2_101.disp d ON client.client_id = d.client_id
JOIN financial2_101.loan l ON l.account_id = d.account_id
WHERE EXTRACT(YEAR FROM client.birth_date) > 1990
      ;
#This part was fairly intuitive, because I figured that milenials are far less likely to have loans, and in
#a previous query, we determined the average age of borrowers to be around 66 years.


# Expiring cards (result is the csv file cards_at_expiration)
# Write a procedure to refresh the table you created (you can call it e.g. cards_at_expiration) containing the following columns:
#
# client_id,
# card_id,
# expiration_date - assume that the card can be active for 3 years after issue date,
# client_address (column A3 is enough).

CREATE TABLE cards_at_expiration AS
SELECT
    client.client_id,
    c.card_id,
    DATE_ADD(c.issued, INTERVAL 3 YEAR) AS expiration_date,
    d2.A3
FROM financial2_101.client
JOIN financial2_101.disp d ON client.client_id = d.client_id
JOIN financial2_101.card c ON d.disp_id = c.disp_id
JOIN financial2_101.district d2 on client.district_id = d2.district_id;

#I forgot to change the column name in the previous query, so I'm doing it here.
ALTER TABLE cards_at_expiration
CHANGE COLUMN A3 address VARCHAR(255);

SELECT * FROM cards_at_expiration;
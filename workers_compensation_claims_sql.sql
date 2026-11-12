select * from worker_compensation_claims;


-- How many total members and claims are there in the worker_compensation_claims table?

SELECT COUNT(DISTINCT member_id) AS total_members,
       COUNT(claim_id) AS total_claims
FROM worker_compensation_claims;
-- So we got 8000 members and 100000 claims in the worker_compensation_claims table.

-- Percentage of claims that are open, pending and closed?
SELECT claim_status,
       COUNT(*) AS claim_count,
       CAST(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM worker_compensation_claims) AS DECIMAL(10,2)) AS percentage
FROM worker_compensation_claims
GROUP BY claim_status;
-- 47.11% Open claims, 44.15% Closed claims, 8.73% Pending claims.

-- What is the average and median incurred cost for each claim status?
WITH ClaimStats AS (
    SELECT
        claim_status,
        incurred_cost,
        AVG(incurred_cost) OVER (
            PARTITION BY claim_status
        ) AS average_claim_amount,
        PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY incurred_cost
        ) OVER (
            PARTITION BY claim_status
        ) AS median_incurred_cost
    FROM worker_compensation_claims
)
SELECT DISTINCT
    claim_status,
    CAST(average_claim_amount AS DECIMAL(10,2)) AS average_claim_amount,
    CAST(median_incurred_cost AS DECIMAL(10,2)) AS median_incurred_cost
FROM ClaimStats
ORDER BY claim_status;
-- Pending and Closed claims have an average of about $11500 and Open has an average of $18000
-- Pending and Closed claims have a median of about $3980 and Open has a median of $6047.

-- How much money is to be settled excluding closed claims?
SELECT SUM(outstanding_reserve) AS total_settlement_amount
FROM worker_compensation_claims
WHERE claim_status != 'Closed';
-- The total settlement amount for open and pending claims is $663948758.30.

-- How much money is to be settled for Closed claims?
SELECT SUM(outstanding_reserve) AS total_settlement_amount
FROM worker_compensation_claims
WHERE claim_status = 'Closed';
-- The total settlement amount for closed claims is $0.00 since they are already settled.

-- Injury causes that cost the most money in terms of incurred cost and number of claims?
SELECT cause_of_injury AS injury_cause,
        workforce_size,
        COUNT(*) AS claim_count,
        SUM(incurred_cost) AS total_incurred_cost
FROM worker_compensation_claims
GROUP BY cause_of_injury, workforce_size
ORDER BY total_incurred_cost DESC;
-- Seems like Manual Handling and Slips, Trips, and Falls are the top causes
-- of injury that cost the most money in terms of incurred cost and number of claims.
-- Small and Medium workforce sizes have the highest incurred costs and claim counts.
-- BR: Include safety enforcement and training programs to reduce these types of injuries.

-- Which Injury costs the most per claim?
SELECT DISTINCT cause_of_injury AS injury_cause,
       PERCENTILE_CONT(0.5) WITHIN GROUP (
            ORDER BY incurred_cost
        ) OVER (
            PARTITION BY cause_of_injury
        ) AS median_incurred_cost
FROM worker_compensation_claims
ORDER BY median_incurred_cost DESC;
-- Exposure, Machinery and Slips, Trips, and Falls are the top causes of injury that cost the most on average per claim.

-- Most common injury caused in each member_sector?
WITH RankedInjuries AS (
    SELECT member_sector,
           cause_of_injury,
           RANK() OVER (PARTITION BY member_sector ORDER BY SUM(incurred_cost) DESC) AS injury_rank,
--           RANK() OVER (PARTITION BY member_sector ORDER BY COUNT(*) DESC) AS injury_rank,
           COUNT(*) AS claim_count,
           SUM(incurred_cost) AS total_incurred_cost
    FROM worker_compensation_claims
    GROUP BY member_sector, cause_of_injury
)
SELECT member_sector,
        cause_of_injury AS most_common_injury,
        claim_count,
        total_incurred_cost
FROM RankedInjuries
WHERE injury_rank = 1;
-- The most common injury caused in each member_sector seems to be manual handling
-- with the highest claim counts and incurred costs across various sectors.
-- BR: Implementing targeted safety measures and training programs in these sectors
-- could help reduce the frequency and severity of these injuries.

-- Injurty types that causes the most delay for return to work?
SELECT DISTINCT injury_type,
       CAST(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY return_to_work_days)
       OVER (PARTITION BY injury_type) AS DECIMAL(10,2)) AS median_days_to_return_to_work
FROM worker_compensation_claims
ORDER BY median_days_to_return_to_work DESC;
-- Major Physical and Psychological injuries cause the most delay for return to work, 
-- with a median of 63 and 55 days respectively.

-- How much average delay in reviewing claims for each team?
SELECT team,
       AVG(review_overdue_days) AS average_review_days
FROM worker_compensation_claims
GROUP BY team
ORDER BY average_review_days DESC;
-- Complex Claims and Recovery Support teams have the highest average delay in reviewing claims, with 16.16 and 7.21 days respectively.

-- Lets check if the delay in reviewing claims is caused by system_issues
SELECT team,
        AVG(review_overdue_days) AS avg_review_overdue_days,
        system_issue_flag,
        COUNT(*) AS claim_count,
        RANK() OVER (PARTITION BY team ORDER BY AVG(review_overdue_days) DESC) AS review_delay_rank
FROM worker_compensation_claims
GROUP BY team, system_issue_flag
-- BR: Even though the system issues are causing a bit of delay which should not happen 
-- for the complex claims at bare minimum since it has the highest incurred cost, 
-- we should try to reduce the delay in atleast the Complex Claims team by streamling
-- the process and providing additional resources to handle the claims more efficiently.

-- Does system issue have any correlation with rework on the claims?
SELECT system_issue_flag,
       CAST(AVG(rework_count) AS DECIMAL(10,2)) AS avg_rework_count,
       (COUNT(*)*1.0/ (SELECT COUNT(*) FROM worker_compensation_claims)*100.0) AS claim_count_percentage
FROM worker_compensation_claims
GROUP BY system_issue_flag;
-- The average rework count is higher for claims with system issues (2.66) compared to those without (0.65).
-- This suggests that system issues contribute to increased rework on claims, which can lead to delays and additional costs.
-- BR: Addressing system issues could help reduce rework and improve overall claim processing efficiency.

-- Injury date to closure date for closed claims?
SELECT cause_of_injury,
        AVG(DATEDIFF(day, injury_date, closure_date)) AS avg_days_to_close_claim,
        AVG(return_to_work_days) AS avg_days_to_return_to_work,
        AVG(incurred_cost) AS avg_incurred_cost
FROM worker_compensation_claims
WHERE claim_status = 'Closed'
GROUP BY cause_of_injury
ORDER BY avg_days_to_close_claim DESC;
-- Exposure, Other and Repetitive Movement injuries take the longest to close.

-- Injury date to lodgement date for open and pending claims?
SELECT cause_of_injury,
        AVG(DATEDIFF(day, injury_date, lodgement_date)) AS avg_days_to_lodge_claim,
        AVG(incurred_cost) AS avg_incurred_cost
FROM worker_compensation_claims
WHERE claim_status IN ('Open', 'Pending')
GROUP BY cause_of_injury
ORDER BY avg_days_to_lodge_claim DESC;
-- Approximately 15 days on average to lodge a claim for most issues, 
-- BR: Such delays cost the worker and the organization time and money respectively.
-- We should implement an automated system and reduce the average days to lodge a claim.
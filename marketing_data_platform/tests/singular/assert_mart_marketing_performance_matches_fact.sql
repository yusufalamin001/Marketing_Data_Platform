with fact as (

    select count(*) as row_count, sum(spend) as spend
    from {{ ref('fct_marketing_spend') }}

),

mart as (

    select count(*) as row_count, sum(spend) as spend
    from {{ ref('mart_marketing_performance') }}

)

select
    fact.row_count as fact_rows,
    mart.row_count as mart_rows,
    fact.spend     as fact_spend,
    mart.spend     as mart_spend
from fact
cross join mart
where fact.row_count != mart.row_count
   or abs(fact.spend - mart.spend) > 0.01
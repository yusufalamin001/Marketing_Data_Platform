with upstream as (

    select platform, count(*) as row_count, sum(spend) as spend
    from {{ ref('int_marketing_ads') }}
    group by platform

),

fact as (

    select platform, count(*) as row_count, sum(spend) as spend
    from {{ ref('fct_marketing_spend') }}
    group by platform

)

select
    upstream.platform,
    upstream.row_count as upstream_rows,
    fact.row_count     as fact_rows,
    upstream.spend     as upstream_spend,
    fact.spend         as fact_spend
from upstream
left join fact
    on upstream.platform = fact.platform
where fact.platform is null
   or upstream.row_count != fact.row_count
   or abs(upstream.spend - fact.spend) > 0.01
with staged as (

    select 'facebook' as platform, sum(spend) as spend
    from {{ ref('stg_facebook_ads_stats') }}

    union all

    select 'snapchat' as platform, sum(spend) as spend
    from {{ ref('stg_snapchat_ads_stats') }}

),

modelled as (

    select platform, sum(spend) as spend
    from {{ ref('int_marketing_ads') }}
    group by platform

)

select
    staged.platform,
    staged.spend  as staged_spend,
    modelled.spend as modelled_spend
from staged
left join modelled using (platform)
where modelled.spend is null
   or abs(staged.spend - modelled.spend) > 0.01
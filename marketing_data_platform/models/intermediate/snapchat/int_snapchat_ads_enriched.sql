with daily as (

    -- roll country rows up to one row per ad per day, the Facebook grain
    select
        ad_id,
        report_date,
        currency_code,
        sum(spend)        as spend,
        sum(impressions)  as impressions,
        sum(clicks)       as clicks
    from {{ ref('stg_snapchat_ads_stats') }}
    group by ad_id, report_date, currency_code

)

select
    'snapchat'                       as platform,
    daily.report_date,
    campaigns.account_id,
    daily.currency_code,
    adgroups.campaign_id,
    campaigns.campaign_name,
    ads.ad_group_id,
    adgroups.ad_group_name,
    daily.ad_id,
    ads.ad_name,
    cast(daily.spend as decimal(18, 6)) as spend,
    daily.impressions,
    daily.clicks
from daily
left join {{ ref('stg_snapchat_ads_ads') }} as ads
    on daily.ad_id = ads.ad_id
left join {{ ref('stg_snapchat_ads_adgroups') }} as adgroups
    on ads.ad_group_id = adgroups.ad_group_id
left join {{ ref('stg_snapchat_ads_campaigns') }} as campaigns
    on adgroups.campaign_id = campaigns.campaign_id
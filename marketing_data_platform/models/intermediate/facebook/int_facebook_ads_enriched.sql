select
    'facebook'                              as platform,
    stats.report_date,
    stats.account_id,
    accounts.currency_code,
    ads.campaign_id,
    campaigns.campaign_name,
    ads.ad_group_id,
    adgroups.ad_group_name,
    stats.ad_id,
    ads.ad_name,
    cast(stats.spend as decimal(18, 6))     as spend,
    stats.impressions,
    stats.clicks
from {{ ref('stg_facebook_ads_stats') }} as stats
left join {{ ref('stg_facebook_ads_ads') }} as ads
    on stats.ad_id = ads.ad_id
left join {{ ref('stg_facebook_ads_adgroups') }} as adgroups
    on ads.ad_group_id = adgroups.ad_group_id
left join {{ ref('stg_facebook_ads_campaigns') }} as campaigns
    on ads.campaign_id = campaigns.campaign_id
left join {{ ref('stg_facebook_ads_accounts') }} as accounts
    on stats.account_id = accounts.account_id
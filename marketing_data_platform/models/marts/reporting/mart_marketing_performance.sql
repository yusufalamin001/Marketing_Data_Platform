select
    fct.marketing_spend_key,
    fct.platform,
    fct.report_date,
    fct.account_id,
    fct.currency_code,
    campaigns.campaign_id,
    campaigns.campaign_name,
    ads.ad_group_id,
    ads.ad_group_name,
    ads.ad_id,
    ads.ad_name,
    ads.ad_status,
    fct.spend,
    fct.impressions,
    fct.clicks,
    fct.ctr,
    fct.cpc,
    fct.cpm
from {{ ref('fct_marketing_spend') }} as fct
left join {{ ref('dim_campaign') }} as campaigns
    on fct.campaign_key = campaigns.campaign_key
left join {{ ref('dim_ad') }} as ads
    on fct.ad_key = ads.ad_key
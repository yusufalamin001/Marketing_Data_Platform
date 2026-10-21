with facebook as (

    select
        'facebook'                       as platform,
        ads.ad_id,
        ads.ad_name,
        cast(ads.ad_status as string)    as ad_status,
        ads.ad_group_id,
        adgroups.ad_group_name,
        ads.campaign_id
    from {{ ref('stg_facebook_ads_ads') }} as ads
    left join {{ ref('stg_facebook_ads_adgroups') }} as adgroups
        on ads.ad_group_id = adgroups.ad_group_id

),

snapchat as (

    select
        'snapchat'                       as platform,
        ads.ad_id,
        ads.ad_name,
        cast(null as string)             as ad_status,
        ads.ad_group_id,
        adgroups.ad_group_name,
        adgroups.campaign_id
    from {{ ref('stg_snapchat_ads_ads') }} as ads
    left join {{ ref('stg_snapchat_ads_adgroups') }} as adgroups
        on ads.ad_group_id = adgroups.ad_group_id

),

unioned as (

    select * from facebook
    union all
    select * from snapchat

)

select
    {{ dbt_utils.generate_surrogate_key(['platform', 'ad_id']) }} as ad_key,
    platform,
    ad_id,
    ad_name,
    ad_status,
    ad_group_id,
    ad_group_name,
    campaign_id,
    -- a missing campaign must stay null, not become a placeholder hash
    case
        when campaign_id is null then null
        else {{ dbt_utils.generate_surrogate_key(['platform', 'campaign_id']) }}
    end as campaign_key
from unioned
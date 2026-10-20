with source as (

    select * from {{ source('facebook_ads', 'accounts') }}

),

renamed as (

    select
        cast(account_id as string)            as account_id,
        account_name,
        upper(ad_currency_code)               as currency_code,
        cast(account_created_at as timestamp) as account_created_at,
        cast(account_updated_at as timestamp) as account_updated_at
    from source

)

select * from renamed
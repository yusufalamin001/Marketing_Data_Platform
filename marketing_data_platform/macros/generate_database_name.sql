{% macro generate_database_name(custom_database_name=none, node=none) -%}
    {%- if target.name in ['staging', 'production'] and custom_database_name is not none -%}
        {{ custom_database_name | trim }}_{{ target.name }}
    {%- else -%}
        {{ target.database }}
    {%- endif -%}
{%- endmacro %}
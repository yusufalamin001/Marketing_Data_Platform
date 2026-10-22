{% macro drop_ci_schema() %}
    {# Guard rails: this may only ever drop throwaway pull request schemas. #}
    {% if target.name != 'ci' %}
        {{ exceptions.raise_compiler_error("drop_ci_schema only runs on the ci target, not " ~ target.name) }}
    {% endif %}
    {% if not target.schema.startswith('pr_') %}
        {{ exceptions.raise_compiler_error("Refusing to drop schema '" ~ target.schema ~ "'. CI schemas must start with pr_") }}
    {% endif %}

    {% for schema in [target.schema, target.schema ~ '_elementary'] %}
        {% do run_query('drop schema if exists ' ~ target.database ~ '.' ~ schema ~ ' cascade') %}
        {{ log('Dropped ' ~ target.database ~ '.' ~ schema, info=True) }}
    {% endfor %}
{% endmacro %}
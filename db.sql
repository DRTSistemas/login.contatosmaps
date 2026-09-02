WITH
base AS (
  SELECT
    e.cnpj_basico, e.cnpj_ordem, e.cnpj_dv,
    e.identificador_matriz_filial, e.nome_fantasia,
    e.situacao_cadastral, e.data_situacao_cadastral, e.motivo_situacao_cadastral,
    e.logradouro, e.numero, e.complemento, e.cep, e.bairro,
    e.municipio, e.uf, e.data_inicio_atividade,
    e.ddd_1, e.telefone_1, e.ddd_2, e.telefone_2,
    e.correio_eletronico, e.situacao_especial,
    e.cnae_fiscal_principal, e.cnae_fiscal_secundaria
  FROM public.estabelecimento e
  WHERE e.uf = 'RS'
    AND e.situacao_cadastral = 2
    AND e.identificador_matriz_filial = 1
    AND e.cnae_fiscal_principal = 6622300
),
socios_aggr AS (
  SELECT
    s.cnpj_basico,
    STRING_AGG(s.nome_socio_razao_social, ' | ' ORDER BY s.nome_socio_razao_social) AS socios
  FROM public.socios s
  JOIN base b ON b.cnpj_basico = s.cnpj_basico
  GROUP BY s.cnpj_basico
),
ativ_sec AS (
  SELECT
    b.cnpj_basico, b.cnpj_ordem, b.cnpj_dv,
    STRING_AGG(DISTINCT c.codigo::text, ', ' ORDER BY c.codigo::text) AS codigos_ativ_sec,
    STRING_AGG(DISTINCT c.descricao, ' | ' ORDER BY c.descricao)       AS descricoes_ativ_sec
  FROM base b
  LEFT JOIN LATERAL (
    SELECT regexp_split_to_table(COALESCE(b.cnae_fiscal_secundaria,''), '[^0-9]+') AS codigo_txt
  ) s ON s.codigo_txt ~ '^[0-9]+$'
  LEFT JOIN public.cnae c ON c.codigo::int = s.codigo_txt::int
  GROUP BY b.cnpj_basico, b.cnpj_ordem, b.cnpj_dv
)

SELECT
  CONCAT(b.cnpj_basico, b.cnpj_ordem, b.cnpj_dv)                       AS "CNP",
  b.cnpj_basico                                                        AS "Raiz CNPJ",
  emp.razao_social                                                     AS "Razao Social",
  CASE WHEN b.identificador_matriz_filial = 1 THEN 'MATRIZ' ELSE 'FILIAL' END AS "Matriz Filial",

  emp.natureza_juridica                                                AS "Codigo Natureza Juridica",
  nj.descricao                                                         AS "Descricao Natureza Juridica",

  b.nome_fantasia                                                      AS "Nome Fantasia",
  b.situacao_cadastral                                                 AS "Situacao Cadastral",
  CASE
    WHEN b.data_situacao_cadastral BETWEEN 19000101 AND 20991231
      THEN TO_DATE(b.data_situacao_cadastral::text, 'YYYYMMDD')
  END                                                                  AS "Data Situacao Cadastral",
  m.descricao                                                          AS "Motivo Situacao Cadastral",

  b.logradouro                                                         AS "Logradouro",
  b.numero                                                             AS "Numero",
  b.complemento                                                        AS "Complemento",
  b.cep                                                                AS "CEP",
  b.bairro                                                             AS "Bairro",
  mu.descricao                                                         AS "Municipio",
  b.uf                                                                 AS "UF",

  CASE
    WHEN b.data_inicio_atividade BETWEEN 19000101 AND 20991231
      THEN TO_DATE(b.data_inicio_atividade::text, 'YYYYMMDD')
  END                                                                  AS "Data de Abertura",
  CONCAT_WS('', b.ddd_1, b.telefone_1)                                 AS "Telefones",
  b.correio_eletronico                                                 AS "E-mail",

  emp.capital_social                                                   AS "Capital Social",
  b.situacao_especial                                                  AS "Situacao Especial",

  b.cnae_fiscal_principal                                              AS "Codigo da Atividade Principal",
  cpr.descricao                                                        AS "Descricao da Atividade Principal",

  atv.descricoes_ativ_sec                                              AS "Atividades Secundarias",
  atv.codigos_ativ_sec                                                 AS "Codigos das Atividades Secundarias",
  atv.descricoes_ativ_sec                                              AS "Descrição das Atividades Secundarias",

  b.municipio                                                          AS "Codigo IBGE do municipio",
  CURRENT_DATE                                                         AS "Data da Consulta",
  sa.socios                                                            AS "Socios",

  emp.porte_empresa                                                    AS "Porte da Empresa",
  emp.ente_federativo_responsavel                                      AS "Ente Federativo Responsavel",

  si.opcao_mei                                                         AS "Optante MEI",
  CASE WHEN si.data_opcao_mei BETWEEN 19000101 AND 20991231
         THEN TO_DATE(si.data_opcao_mei::text, 'YYYYMMDD') END         AS "Data de Opção MEI",
  CASE WHEN si.data_exclusao_mei BETWEEN 19000101 AND 20991231
         THEN TO_DATE(si.data_exclusao_mei::text, 'YYYYMMDD') END      AS "Data Exclusão MEI",
  si.opcao_pelo_simples                                                AS "Optante Simples",
  CASE WHEN si.data_opcao_simples BETWEEN 19000101 AND 20991231
         THEN TO_DATE(si.data_opcao_simples::text, 'YYYYMMDD') END     AS "Data de Opção Simples",
  CASE WHEN si.data_exclusao_simples BETWEEN 19000101 AND 20991231
         THEN TO_DATE(si.data_exclusao_simples::text, 'YYYYMMDD') END  AS "Data Exclusão Simple"

FROM base b
JOIN public.empresa emp
  ON emp.cnpj_basico = b.cnpj_basico
 AND emp.natureza_juridica IN (0,2062,2070,2089,2097,2100,2127,2143,2151,2160,2232,2240,2259,2267,2305,2313,8885)
LEFT JOIN public.natju  nj  ON nj.codigo::int  = emp.natureza_juridica
LEFT JOIN public.moti   m   ON m.codigo::int   = b.motivo_situacao_cadastral
LEFT JOIN public.cnae   cpr ON cpr.codigo::int = b.cnae_fiscal_principal
LEFT JOIN public.munic  mu  ON mu.codigo       = b.municipio
LEFT JOIN public.simples si ON si.cnpj_basico  = b.cnpj_basico
LEFT JOIN ativ_sec atv       ON atv.cnpj_basico = b.cnpj_basico
                            AND atv.cnpj_ordem  = b.cnpj_ordem
                            AND atv.cnpj_dv     = b.cnpj_dv
LEFT JOIN socios_aggr sa     ON sa.cnpj_basico  = b.cnpj_basico
ORDER BY emp.razao_social, b.nome_fantasia;

verbose =
  Documentation:
    id: '{subtype} #'
    title: '{article_title}'
  Phenotype:
    id: '{species} Phenotype #'

_make_string = (r,template) ->
  return template.replace(/\{(.*?)\}/g,((g0,g1) -> r.best(g1)))

window.fixes ?= {}
window.fixes.fix_terse =
  fixes:
    global: [
      (data) ->
        data.tp2_row.register 100, () -> # Subtypes for doucmentation
          url = data.tp2_row.best('domain_url')
          data.tp2_row.candidate('subtype','ID',10)
          m = url.match /Help\/([a-zA-z]+)/
          if m?
            data.tp2_row.candidate('subtype',m[1],100)

        data.tp2_row.register 300, () -> # Overly terse titles
          ft = data.tp2_row.best('feature_type')
          v = verbose[ft]
          if v?.title?
            t = data.tp2_row.best('main-title')
            data.tp2_row.candidate('main-title',_make_string(data.tp2_row,v.title),300)
          if v?.id?
            id = data.tp2_row.best('id')
            id = _make_string(data.tp2_row,v.id) + id
            data.tp2_row.candidate('id',id,300)
        true
    ]

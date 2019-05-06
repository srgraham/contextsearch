

$ ()->

  arr = [
    {abc: 'abc', def: 'def', ghi: 'ghi'}
    {abc: 'bcd', def: 'efg', ghi: 'hij'}
    {abc: 'cde', def: 'fgh', ghi: 'ijk'}
    {abc: 122, def: 455, ghi: 788}
    {abc: '123', def: '456', ghi: '789'}
    {abc: 123, def: 456, ghi: 789}
    {abc: 124, def: 457, ghi: 790}
  ]

  column_name_to_path_obj = {
    'Alphabet': 'abc'
    'Guy': 'ghi'
    'abc'
    'def'
    'ghi'
  }


  class ContextSearch
    constructor: (rows, column_name_to_path_obj)->
      @setRows rows, column_name_to_path_obj
      return

    setRows: (rows, column_name_to_path_obj)->
      @rows = rows
      @column_name_to_path_obj = column_name_to_path_obj

      @dirty =
        filtered_indicies: true
        autocomplete: true

      @filtered_indicies = []
      @uniq_column_paths = @calcUniqColumnPaths()
      @rows_compact = @calcCompactRows()
      @uniq_column_names = @calcUniqColumnNames()

      console.log 'this', @

      return

    calcAutocompleteValues: ()->
      out = {}
      paths = @uniq_column_paths
      rows = @rows_compact

      _.each paths, (path)->

        counts = _.countBy rows, path

        sorted_objs = _.chain(counts).map((count, value)->
          out =
            value: value
            count: count
          return out
        ).sortBy('count').reverse().value()
        out[path] = _.map sorted_objs, 'value'
        return

      return out

    # takes _.at obj.a.b.c and flattens it to the key string literal "obj.a.b.c" being the value of obj.a.b.c
    calcCompactRows: ()->
      rows = @rows
      paths = @uniq_column_paths

      out = {}
      _.each rows, (obj, key)->
        out[key] = {}
        values = _.at obj, paths
        _.each paths, (path, i)->
          out[key][path] = values[i]
        return
      return out

    calcUniqColumnPaths: ()->
      return _.uniq(_.flatten(_.values(@column_name_to_path_obj))) || []

    calcUniqColumnNames: ()->
      return (_.uniq _.flattenDeep [
        _.keys @column_name_to_path_obj,
        _.values @column_name_to_path_obj
      ]) || []

    columnNameToPaths: (column)->
      out = @column_name_to_path_obj[column]
      if not _.isArray out
        if out
          out = [out]
        else
          out = []

      if _.includes(@uniq_column_paths, column) and not _.includes(out, column)
        out.push column

      if out.length is 0
        return null

      return out

    filter: (filter)->
      filter_objs = _.compact peg.parse filter
      console.log 111, filter_objs

      handleFilterObj = (filter_obj)=>

        msg = ''
        cb = ->
          throw new Error "Unhandled function result from #filter(#{JSON.stringify(filter_obj)})"
        errs = []

        switch filter_obj.type
          when 'Expression'
            column = filter_obj.column.value.value
            operator = filter_obj.operator.value
            search_obj = filter_obj.value

            column_paths = @columnNameToPaths column

            # wrap in anonymous func so we can break out of the switch with a return statement
            (()->
              if not column_paths
                cb = ->true
                err = new Error "No column_paths could be found for column '#{column}'"
                errs.push err
                cb.debug = err.message
                return

              if not search_obj
                cb = ->true
                cb.debug = _.map(column_paths, (column_path)->
                  return "#{column_path} #{operator} ?"
                ).join ' OR '
                return

              search = search_obj.value

              operatorValueToFunc = (operator, search)->

                fn = ->

                switch operator
                  when "="
                    ((column_paths_scoped, search)->
                      regex = new RegExp _.escapeRegExp(search), 'i'
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return regex.test obj[column_path_scoped]
                    )(column_paths, search)

                  when "==="
                    ((column_paths_scoped, search)->
                      regex = new RegExp "^#{_.escapeRegExp(search)}$", 'i'
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return regex.test obj[column_path_scoped]
                    )(column_paths, search)

                  when "!="
                    fn = _.negate operatorValueToFunc '=', search

                  when "!=="
                    fn = _.negate operatorValueToFunc '===', search

                  when ">"
                    ((column_paths_scoped, search)->
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return obj[column_path_scoped] > search
                    )(column_paths, search)

                  when ">="
                    ((column_paths_scoped, search)->
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return obj[column_path_scoped] >= search
                    )(column_paths, search)

                  when "<"
                    ((column_paths_scoped, search)->
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return obj[column_path_scoped] < search
                    )(column_paths, search)

                  when "<="
                    ((column_paths_scoped, search)->
                      fn = (obj)->
                        return _.some column_paths_scoped, (column_path_scoped)->
                          return obj[column_path_scoped] <= search
                    )(column_paths, search)

                fn.debug = _.map(column_paths, (column_path)->
                  return "#{column_path} #{operator} '#{search}'"
                ).join ' OR '
                return fn

              cb = operatorValueToFunc operator, search
              return

            )()

          when 'FullSearch'
            search = filter_obj.value.value

            paths = @uniq_column_paths
            regex = new RegExp _.escapeRegExp(search), 'i'

            column_name_paths = @columnNameToPaths search

            # if we found something, they entered a column name
            if column_name_paths
              cb = (obj)->
                return _.some column_name_paths, (path)->
                  return obj[path]

              cb.debug = _.map(column_name_paths, (column_path)->
                return "'#{column_path}' is true"
              ).join ' OR '

            else

              # otherwise, search all columns for matching text
              cb = (obj)->
                return _.some paths, (path)->
                  return regex.test obj[path]
              cb.debug = "* = #{search}"

          when 'OrGroup'
            left = handleFilterObj filter_obj.left
            right = handleFilterObj filter_obj.right
            errs.push left.errs...
            errs.push right.errs...

            cb = (obj)->
              return left.cb(obj) || right.cb(obj)

            cb.debug = "#{left.cb.debug} OR #{right.cb.debug}"

          when 'AndGroup'
            left = handleFilterObj filter_obj.left
            right = handleFilterObj filter_obj.right
            errs.push left.errs...
            errs.push right.errs...

            cb = (obj)->
              return left.cb(obj) && right.cb(obj)

            cb.debug = "#{left.cb.debug} AND #{right.cb.debug}"

          when 'Group'
            where = handleFilterObj filter_obj.where
            cb = where.cb
            errs.push where.errs...

          when 'EOF'
            cb.debug = 'EOF';

          when 'JUNK'
            err = new Error "'#{filter_obj.value}' could not be understood."
            cb = ->true
            cb.debug = err.msg
            errs.push err


        out =
          errs: errs
          cb: cb
          msg: msg

        return out

      filter_funcs = []
      errors = []

      _.each filter_objs, (filter_obj)->
        {cb, errs} = handleFilterObj filter_obj
        errors.push errs...
        filter_funcs.push cb
        return

      @dirty =
        filtered_indicies: true
        autocomplete: true

      @filter_objs = filter_objs
      @filter_funcs = filter_funcs
      @errors = _.uniq errors
      @debugs = _.uniq _.compact _.map filter_funcs, 'debug'

      out =
        filter_objs: @filter_objs
        filter_funcs: @filter_funcs
        errors: @errors
        debugs: @debugs

      return out

    getFilteredIndicies: ()->
      # use the cache if they haven't changed the filter
      if not @dirty.filtered_indicies
        return @filtered_indicies

      # otherwise, rebuild list by running all the funcs against each row
      filtered_indicies = []
      _.each @rows_compact, (row, key)=>
        should_show = _.every @filter_funcs, (cb)->
          return cb row

        if should_show
          filtered_indicies.push key
        return

      @filtered_indicies = filtered_indicies
      @dirty.filtered_indicies = false

      return @filtered_indicies

  context_search = new ContextSearch arr, column_name_to_path_obj

  $ul = $('#results')
  $.each arr, (index)->
    $li = $('<li>').attr('id', "row-#{index}")

    $li.text JSON.stringify arr[index]

    $ul.append $li
    return


  $('#search').on 'keyup', (e)->


    filter = e.target.value
    filter_out = context_search.filter filter

    console.log filter_out

    filtered_arr_indices = context_search.getFilteredIndicies()

    $ul.find('li').addClass 'hidden'

    console.log 555, context_search.calcAutocompleteValues()

    $.each filtered_arr_indices, (z, index)->
      $("#row-#{index}").removeClass 'hidden'
      return


    return


  $('#search').trigger('keyup');



  return


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

    OPERATORS = [
      ":"
      "="
      "=="
      "==="
      "<>"
      "!="
      "!=="
      ">="
      "=>"
      "<="
      "=<"
      ">"
      "<"
    ]

    setRows: (rows, column_name_to_path_obj)->
      @rows = rows
      @column_name_to_path_obj = column_name_to_path_obj

      @dirty =
        filtered_indicies: true
        autocomplete: true

      @filtered_indicies = []
      @uniq_column_paths = @_calcUniqColumnPaths()
      @rows_compact = @_calcCompactRows()
      @uniq_column_names = @_calcUniqColumnNames()
      @autocomplete_values = @_calcAutocompleteValues()
      @autocomplete_allowed_length = 10

      console.log 'this', @

      return

    _onSelect: (selected_value, selected_value_obj)->
      return

    _calcAutocompleteValues: ()->
      out = {}
      paths = @uniq_column_paths
      rows = @rows_compact

      _.each paths, (path)->

        counts = _.countBy rows, path

        sorted_objs = _.chain(counts).map((count, value)->
          out_obj =
            value: value
            count: count
          return out_obj
        ).sortBy('count').reverse().value()

        out[path] = _.map sorted_objs, 'value'

        return

      return out

    # takes _.at obj.a.b.c and flattens it to the key string literal "obj.a.b.c" being the value of obj.a.b.c
    _calcCompactRows: ()->
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

    _calcUniqColumnPaths: ()->
      return _.uniq(_.flatten(_.values(@column_name_to_path_obj))) || []

    _calcUniqColumnNames: ()->
      return (_.uniq _.flattenDeep [
        _.keys @column_name_to_path_obj,
        _.values @column_name_to_path_obj
      ]) || []

    _columnNameToPaths: (column)->
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

            column_paths = @_columnNameToPaths column

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

            column_name_paths = @_columnNameToPaths search

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

          when 'Regex'
            regex = filter_obj.regex

            paths = @uniq_column_paths

            # otherwise, search all columns for matching text
            cb = (obj)->
              return _.some paths, (path)->
                # regex could have "g" or "y" flag, so reset lastIndex every time
                regex.lastIndex = 0
                return regex.test obj[path]
            cb.debug = "* REGEX #{regex}"

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

    getAutocompleteAtPos: (caret_pos)->
      self = this

      # FIXME: i dont think this works on nested wheres
      _objIsAtCursor = (obj)->

        location = obj.location
        if not location
          return false

        start = location.start.offset
        end = location.end.offset

        console.log 123, start, end, caret_pos

        return start <= caret_pos <= end

      filter_obj_at_caret = _.find(@filter_objs, _objIsAtCursor) || {type: 'NoMatch'}

      _getAutocompleteForObj = (obj)->

        autocompletes = []
        autocomplete_value = null
        autocomplete_value_add_character = ''

        location =
          start: offset: caret_pos
          end: offset: caret_pos

        # wrap switch in anonymous func so we can break out of it with a return
        (->

          console.log obj.type

          switch obj.type
            when 'Expression'
              if _objIsAtCursor obj.column
                console.log 'COLUMN'
                autocompletes = self._autocompleteColumnName obj.column.value.value
                autocomplete_value = obj.column.value.value
                location = obj.column.location
                return

              if _objIsAtCursor obj.operator
                console.log 'OPERATOR', self._autocompleteOperator(obj.operator.str)
                autocompletes = [
                  self._autocompleteColumnValue(obj.column.value.value, '')...
                  self._autocompleteOperator(obj.operator.str)...
                ]
                if obj.operator.str.length > 0
                  autocomplete_value = obj.operator.str
                  location =
                    start: obj.location.end
                    end: obj.location.end

                return

              console.log 'VALUE'
              # otherwise, its at the value
              autocomplete_value = obj.value?.value || ''
              autocompletes = self._autocompleteColumnValue obj.column.value.value, autocomplete_value
              autocomplete_value_add_character = ' '
              location = (obj.value || obj.column.value).location

              if not location
                location =
                  start: obj.operator.location.end
                  end: obj.location.end

        )()

        out_obj =
          autocompletes: _.uniqBy(autocompletes, 'value').slice 0, self.autocomplete_allowed_length
          autocomplete_value: autocomplete_value
          autocomplete_value_add_character: autocomplete_value_add_character
          location: location

        return out_obj


      out = _getAutocompleteForObj filter_obj_at_caret

      return out

    _autocompleteStrsToObj: (strs, additional_text='')->
      out = _.map strs, (str)->
        a_out =
          value: str
          suffix_str: additional_text
        return a_out
      return out

    _autocompleteColumnName: (value)->
      column_names = @uniq_column_names

      regex = new RegExp _.escapeRegExp(value), 'i'
      column_predictions = _.filter column_names, (column_name)->
        return regex.test column_name

      out = @_autocompleteStrsToObj column_predictions, '='
      return out

    _autocompleteOperator: (value='')->

      regex = new RegExp "^#{_.escapeRegExp(value)}", 'i'

      operator_predictions = _.filter OPERATORS, (operator)->
        return regex.test operator

      out = @_autocompleteStrsToObj operator_predictions, ''

      return out

    _autocompleteColumnValue: (column_name, value='')->

      column_paths = @_columnNameToPaths column_name

      regex = new RegExp _.escapeRegExp(value), 'i'

      value_predictions = []

      _.each column_paths, (column_path)=>
        matches = _.filter @autocomplete_values[column_path], (val)->
          return regex.test val

        value_predictions.push matches...

      out = @_autocompleteStrsToObj value_predictions, ' '

      return out

  context_search = new ContextSearch arr, column_name_to_path_obj

  $ul = $('#results')
  $.each arr, (index)->
    $li = $('<li>').attr('id', "row-#{index}")

    $li.text JSON.stringify arr[index]

    $ul.append $li
    return


  $('#search').on 'keyup', (e)->

    input = e.target
    caret_pos = input.selectionStart

#    caret_pos = 18 # FIXME

    filter = input.value

    filter_out = context_search.filter filter

    console.log filter_out

    filtered_arr_indices = context_search.getFilteredIndicies()

    $ul.find('li').addClass 'hidden'

    console.log 555, context_search._calcAutocompleteValues()

    console.log context_search.getAutocompleteAtPos caret_pos

    $.each filtered_arr_indices, (z, index)->
      $("#row-#{index}").removeClass 'hidden'
      return


    return


  $('#search').trigger('keyup');



  return
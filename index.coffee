

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


  filterRows = (rows, filter)->
    console.log 111







    return

  $('#search').on 'keyup', (e)->

    $ul = $('#results')

    $ul.html ''

    filter = e.target.value

    filtered_arr_indices = filterRows arr, filter

    $.each filtered_arr_indices, (z, index)->

      $li = $('<li>')

      $li.text arr[index]

      $ul.append $li

      return


    return


  $('#search').trigger('keyup');



  return
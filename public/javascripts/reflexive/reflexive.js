$(function() {
  $(".opener h2, .opener .trigger").click(function() {
    $(this).parents(".opener").find(".content").toggle();
  });

  $(".lva").click(function(event) {
    event.preventDefault();
    var local_variable_id = $(this).attr("href").match(/\#(.+)$/)[1];
    $(".lva-highlight").removeClass("lva-highlight");
    $("span[id=" + local_variable_id + "]").addClass("lva-highlight");
  });
});

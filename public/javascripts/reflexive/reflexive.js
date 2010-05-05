$(function() {
  $(".opener h2").click(function() {
    $(this).parents(".opener").find(".content").toggle();
  });
});

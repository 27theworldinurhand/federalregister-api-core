$(document).ready(function() {

  $(".section_nav li a").bind('click', function(event) {
    //event.preventDefault();
    $(".section_nav li").removeClass("on");
    $(this).parent().addClass("on");
  });
  
  $(".section_nav li:first-child a").trigger("click");
  
});

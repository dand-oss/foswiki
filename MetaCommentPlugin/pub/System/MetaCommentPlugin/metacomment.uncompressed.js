/*

Foswiki - The Free and Open Source Wiki, http://foswiki.org/

(c)opyright 2010 Michael Daum http://michaeldaumconsulting.com

are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.

*/

jQuery(function($) {
  $(".cmtComments:not(.cmtCommentsInited)").livequery(function() {
    var $this = $(this),
        $container = $this.parent(),
        defaults = {
          topic: foswiki.getPreference("TOPIC"),
          web: foswiki.getPreference("WEB")
        },
        opts = $.extend({}, defaults, $this.metadata());

    /* function to reload all comments *************************************/
    function loadComments(message) {
      var url = foswiki.getPreference("SCRIPTURL") + 
          "/rest/RenderPlugin/template" +
          "?name=metacomments" + 
          ";render=on" +
          ";topic="+opts.web+"."+opts.topic +
          ";expand=metacomments";

      if (!message) {
        message = "Loading ...";
      }
      message = "<h1>"+message+"</h1>";
      $.blockUI({
        message:message,
        fadeIn: 0,
        fadeOut: 0,
        overlayCSS: {
          cursor:'progress'
        }
      });
      $container.load(url, function() {
        $.unblockUI();
        $container.height('auto');
      });
    }

    // add hover 
    $this.find(".cmtComment").hover(
      function() {
        $(this).addClass("cmtHover");
      },
      function() {
        $(this).removeClass("cmtHover");
      }
    );

    // ajaxify add and reply forms
    $this.find(".cmtAddCommentForm").each(function() {
      var $form = $(this), rev, $errorContainer;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          rev = $form.find("input[name=ref]").val(),
          $errorContainer = rev?$this.find("a[name=comment"+rev+"]").parent().parent():$form.parent();

          $this.find(".foswikiErrorMessage").remove();
          $.blockUI({
            message:"<h1>Submitting comment ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function(data, statusText, xhr) {
          $.unblockUI();
          if(data.error) {
            $errorContainer.after("<p><div class='foswikiErrorMessage'>Error: "+data.error.message+"</div></p>");
          } else {
            loadComments();
          }
          $.modal.close();
        },
        error: function(xhr, msg) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $errorContainer.after("<p><div class='foswikiErrorMessage'>Error: "+data.error.message+"</div></p>");
          $.modal.close();
        }
      });
    });

    // ajaxify update form
    $this.find(".cmtUpdateCommentForm").each(function() {
      var $form = $(this), 
          $errorContainer, 
          id, index;

      $form.ajaxForm({
        dataType:"json",
        beforeSubmit: function() {
          id = $form.find("input[name=id]").val();
          index = $form.find("input[name=index]").val();
          $errorContainer = $this.find("a[name=comment"+id+"]").parent().parent();
          $this.find(".foswikiErrorMessage").remove();
          $.blockUI({
            message:"<h1>Updating comment "+index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
        },
        success: function(data, statusText, xhr) {
          $.unblockUI();
          if(data.error) {
            $errorContainer.after("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
          } else {
            loadComments();
          }
          $.modal.close();
        },
        error: function(xhr, msg) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $errorContainer.after("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
          $.modal.close();
        }
      });
    });

    // add reply behaviour
    $this.find(".cmtReply").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata());

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtReplyComment', {
        persist:true,
        close:false,
        containerCss: {
          width:600
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentIndex").text(commentOpts.index);
          dialog.container.find("input[name=ref]").val(commentOpts.id);
        }
      });

      return false;
    });

    // add edit behaviour
    $this.find(".cmtEdit").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata()),
          getUrl = foswiki.getPreference("SCRIPTURL") +
            "/rest/MetaCommentPlugin/handle?action=get" +
            ";topic="+opts.web+"."+opts.topic +
            ";id="+commentOpts.id,
          gotError = false,
          title, text;

      $this.find(".foswikiErrorMessage").remove();
      $.ajax({
        async: false,
        url: getUrl,
        type: "GET",
        dataType: "json",
        success: function(data, msg) {
          $.unblockUI();
          if(data.error) {
            $comment.parent().append("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
            gotError = true;
          } else {
            title = unescape(data.result.title);
            text = unescape(data.result.text);
          }
        },
        error: function(xhr, msg, error) {
          var data = $.parseJSON(xhr.responseText);
          $.unblockUI();
          $comment.parent().append("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
          gotError = true;
        }
      });

      if (!gotError) {
        foswiki.openDialog('#cmtUpdateComment', {
          persist:true,
          close:false,
          containerCss: {
            width:600
          },
          onShow: function(dialog) { 
            dialog.container.find("input[name=id]").val(commentOpts.id);
            dialog.container.find("input[name=index]").val(commentOpts.index);
            dialog.container.find(".cmtCommentIndex").text(commentOpts.index);
            dialog.container.find("input[name=title]").val(title);
            dialog.container.find("textarea[name=text]").val(text);
          }
        });
      }

      return false;
    });

    // add approve behaviour
    $this.find(".cmtApprove").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata()),
          approveUrl = foswiki.getPreference("SCRIPTURL") +
            "/rest/MetaCommentPlugin/handle?action=approve" +
            ";topic="+opts.web+"."+opts.topic +
            ";state=approved" +
            ";id="+commentOpts.id;

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtConfirmApprove', {
        persist:false,
        close:false,
        containerCss: {
          width:300
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentNr").text(commentOpts.index);
          dialog.container.find(".cmtAuthor").text(commentOpts.author);
          dialog.container.find(".cmtDate").text(commentOpts.date);
        },
        onSubmit: function(dialog) {
          $.blockUI({
            message:"<h1>Approving comment "+commentOpts.index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
          $.ajax({
            url: approveUrl,
            type: "GET",
            dataType: "json",
            error: function(xhr, msg, error) {
              var data = $.parseJSON(xhr.responseText);
              $.unblockUI();
              $comment.find(".cmtCommentContainer").append("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
            },
            success: function(data, msg) {
              $.unblockUI();
              loadComments();
            }
          });
        }
      });
      return false;
    });

    // add delete behaviour 
    $this.find(".cmtDelete").click(function() {
      var $comment = $(this).parents(".cmtComment:first"),
          commentOpts = $.extend({}, $comment.metadata()),
          deleteUrl = foswiki.getPreference("SCRIPTURL") +
            "/rest/MetaCommentPlugin/handle?action=delete" +
            ";topic="+opts.web+"."+opts.topic +
            ";id="+commentOpts.id;

      $this.find(".foswikiErrorMessage").remove();

      foswiki.openDialog('#cmtConfirmDelete', {
        persist:false,
        close:false,
        containerCss: {
          width:300
        },
        onShow: function(dialog) { 
          dialog.container.find(".cmtCommentNr").text(commentOpts.index);
          dialog.container.find(".cmtAuthor").text(commentOpts.author);
          dialog.container.find(".cmtDate").text(commentOpts.date);
        },
        onSubmit: function(dialog) {
          $.blockUI({
            message:"<h1>Deleting comment "+commentOpts.index+" ...</h1>",
            fadeIn: 0,
            fadeOut: 0
          });
          $.ajax({
            url: deleteUrl,
            type: "GET",
            dataType: "json",
            error: function(xhr, msg, error) {
              var data = $.parseJSON(xhr.responseText);
              $.unblockUI();
              $comment.find(".cmtCommentContainer").append("<div class='foswikiErrorMessage'>Error: "+data.error.message+"</div>");
            },
            success: function(data, msg) {
              $.unblockUI();
              $comment.slideUp(function() {
                $comment.parent().hide();
                loadComments();
              });
            }
          });
        }
      });
      return false;
    });
  });
});
(function ($) {

  AjaxSolr.FacetFieldWidget = AjaxSolr.AbstractJQueryFacetWidget.extend({
    defaults: {
      templateName: '#solrFacetFieldTemplate',
      container: '.solrFacetFieldContainer',
      hideNullValues: true,
      hideSingle: true,
      name: null,
      dateFormat: null
    },
    facetType: 'facet_queries',
    template: null,
    container: null,
    paramString: null,
    inputType: null,

    initQueries: function() {
      var self = this;
      self.queries = $.parseJSON($(self.target).find(".solrJsonData").text());
    },

    getFacetValue: function(facet) {
      var self = this, query = self.getQueryByKey(facet);
      return (query && query.value)?query.value:facet;
    },

    getFacetKey: function(facet) {
      var self = this, query;

      if (this.options.dateFormat) {
        // SMELL: dependency on jquery.ui.datepicker
        return $.datepicker.formatDate(this.options.dateFormat, new Date(facet));
      }
      
      query = self.getQueryByValue(facet);
      return (query && query.key)?query.key:_(facet);
    },

    afterRequest: function () {
      var self = this,
          thisParamString = self.manager.store.string().replace(/&?start=\d*/g, "");

      // init
      if (self.paramString == thisParamString) {
        return; // no need to render the widget again; just paging
      }

      self.paramString = thisParamString;
      self.facetCounts = self.getFacetCounts();

      if (self.facetCounts.length == 0) {
        self.$target.hide();
        return;
      } 

      if (this.options.hideSingle && self.facetCounts.length == 1) {
        self.$target.hide();
        return;
      } 

      self.container.html($.tmpl(self.template, {
        widget: self
      }, {
        checked: function(facet) {
          return (self.isSelected(facet))?"checked='checked'":"";
        },
        getFacetValue: function(facet) {
          return self.getFacetValue(facet);
        },
        getFacetKey: function(facet) {
          return self.getFacetKey(facet);
        }
      }));
      self.$target.fadeIn();

      self.container.find("input[type='"+self.inputType+"']").change(function() {
        var $this = $(this), 
            title = $this.attr("title"),
            value = $this.val();
        
        if (self.facetType == 'facet_ranges') {
          value = value+' TO '+value+self["facet.range.gap"];
          if (title) {
            AjaxSolr.Dict['default'].set(value, title);
          }
          value = '['+value+']';
        }

        if ($this.is(":checked")) {
          self.clickHandler(value).call(self);
        } else {
          self.unclickHandler(value).call(self);
        }
      });
    },

    init: function() {
      var self = this;

      self.initQueries();

      self._super();
      self.template = $(self.options.templateName).template();
      self.container = self.$target.find(self.options.container);
      self.inputType = 'checkbox'; //(self.options.multiSelect)?'checkbox':'radio';
      self.$target.addClass("solrFacetContainer");
    }

  });

  AjaxSolr.Helpers.build("FacetFieldWidget");


})(jQuery);

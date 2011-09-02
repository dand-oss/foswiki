jQuery(document).ready(function() {

	function sort($el, sort) {
		
		// TODO:

		// sort direction feedback
		// put sort plugin in separate plugin and give author due copyright
		
		var direction = $el.attr('data-sort-direction');
		if (direction === undefined) {
			direction = 1;
		}
		if (sort === 'data-date') {
			// latest on top
			direction = -direction;
		}
		var compare;
		var type = 'string';
		if (sort === 'data-size' || sort === 'data-date') {
			// number
			comparator = function(a, b) {
				return parseInt($(a).attr(sort), 10) > parseInt($(b).attr(sort), 10) ? direction : -direction;
			};
		} else {
			// string
			comparator = function(a, b) {
				return $(a).attr(sort) > $(b).attr(sort) ? direction : -direction;
			};
		}
		// find parent with class 'foswikiAttachments
		var attachments = $el.parents('.foswikiAttachments');
		console.log(attachments);
		$('.foswikiAttachment', attachments).sortElements(comparator);
		/*
		direction = -direction;
		$el.attr('data-sort-direction', direction);
		*/
		return false;
	}
	
	// find currently selected value and sort
	jQuery('select.foswikiSort').livequery(function() {
		sort($(this), $(this).val());
		return false;
	});
	
	jQuery('select.foswikiSort').livequery('change', function() {
		sort($(this), $(this).val());
		return false;
	});
	
	jQuery('a.foswikiSort').livequery('click', function() {
		sort($(this), $(this).attr('data-sort'));
		return false;
	});
});



/**
 * jQuery.fn.sortElements
 * --------------
 * @author James Padolsey (http://james.padolsey.com)
 * @version 0.11
 * @updated 18-MAR-2010
 * --------------
 * @param Function comparator:
 *   Exactly the same behaviour as [1,2,3].sort(comparator)
 *   
 * @param Function getSortable
 *   A function that should return the element that is
 *   to be sorted. The comparator will run on the
 *   current collection, but you may want the actual
 *   resulting sort to occur on a parent or another
 *   associated element.
 *   
 *   E.g. $('td').sortElements(comparator, function(){
 *      return this.parentNode; 
 *   })
 *   
 *   The <td>'s parent (<tr>) will be sorted instead
 *   of the <td> itself.
 */
jQuery.fn.sortElements = (function(){
    
    var sort = [].sort;
    
    return function(comparator, getSortable) {
        
        getSortable = getSortable || function(){return this;};
        
        var placements = this.map(function(){
            
            var sortElement = getSortable.call(this),
                parentNode = sortElement.parentNode,
                
                // Since the element itself will change position, we have
                // to have some way of storing it's original position in
                // the DOM. The easiest way is to have a 'flag' node:
                nextSibling = parentNode.insertBefore(
                    document.createTextNode(''),
                    sortElement.nextSibling
                );
            
            return function() {
                
                if (parentNode === this) {
                    throw new Error(
                        "You can't sort elements if any one is a descendant of another."
                    );
                }
                
                // Insert before flag:
                parentNode.insertBefore(this, nextSibling);
                // Remove flag:
                parentNode.removeChild(nextSibling);
                
            };
            
        });
       
        return sort.call(this, comparator).each(function(i){
            placements[i].call(getSortable.call(this));
        });
        
    };
    
})();
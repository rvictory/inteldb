var debugging = true;
var recordsPerPage = 10;
var currentPage = 1;
var numPages = 1;
var fieldLookup;

$(document).ready(initialize);

//Setup the page initially
function initialize() {
	getLookupTable();
    //Setup left hand navigation
    getNavigation();
    //Request Initial Intel Items
    //getIntelList(0, recordsPerPage, 'initialLoad');
    //Create Pagination
    getPagination();
}

function clearIntelList() {
	$('#accordion2').html('');
}

function expandFirstItem() {
	$('.collapse:first').collapse('show');
}

//This gets the field lookup table to use when building the items
function getLookupTable() {
	$.getJSON('/authenticated/services/schemaList', setLookupTable, onError);
}

function setLookupTable(table) {
	fieldLookup = table;
	getIntelList(0, recordsPerPage, 'initialLoad');
}

function getFieldDescription(field) {
	var toReturn = '';
	for (var i = 0; i < fieldLookup.length; i++) {
		if (fieldLookup[i].field_name == field) {
			toReturn = fieldLookup[i].display_name;
		}
	}
	return toReturn;
}

//Request Left Hand Navigation (tags)
function getNavigation() {
    $.getJSON('/authenticated/services/tagList', displayNavigation, onError);
}

//Build Left Hand Navigation (tags)
function displayNavigation(tags) {
	//Add the tags header
	$('#leftNavigation').append("<li class='nav-header'>Tags</li>");
    if (tags != null) {
    	for (var i = 0; i < tags.length; i++) {
    		$('#leftNavigation').append("<li><a href='#' onclick='tagFilter(\"" + tags[i] + "\", 0, 100)'>" + tags[i] + "</a></li>")
    	}
    }
}

//Filter by tag
function tagFilter(tagName, skip, limit) {
	$.getJSON('/authenticated/services/intelList/tag/' + tagName + '/' + limit + '/' + skip, displayIntelList, onError);
}

//Request a list of Intel Items initially
function getIntelList(skip, limit) {
    //Make Request AJAX
    $.getJSON('/authenticated/services/intelList/query/' + limit + '/' + skip, displayIntelList, onError);
}

//Add a list of intel items to the current list
function displayIntelList(list) {
	clearIntelList();
	$('#noRecordsError').hide();
    //$('#accordion2').append($('#AccordianTemplate').render(list));
    for (var i = 0; i < list.length; i++) {
    	var htmlToRender = $('#AccordianTemplate').html();
    	var contents = '';
    	for (var prop in list[i]) {
    		if (list[i].hasOwnProperty(prop)) {
    			if (prop == 'context') {
    				continue;
    			}
    			var fieldDescription = getFieldDescription(prop);
    			if (fieldDescription != null && fieldDescription != '') {
    				contents += "<div class='item'><b>" + fieldDescription + ":</b><br>" + list[i][prop] + "<br><br></div>";
    			}
    		}
    		
    	}
    	htmlToRender = htmlToRender.replace("{{:contents}}", contents)
    		.replace('{{:source_institution}}', list[i].source_institution)
    		.replace('{{:title}}', list[i].title)
    		.replace('{{:date_added}}', list[i].date_added)
    		.replace(/\{\{\:_id\.\$oid\}\}/g, list[i]._id.$oid)
    		.replace('{{:context}}', list[i].context == null ? '' : list[i].context);
    	$('#accordion2').append(htmlToRender);
    }
    if (list == null || list.length == 0) {
    	$('#noRecordsError').show();
    }
    //expandFirstItem();
}

//Get Pagination Information
function getPagination() {
    $.getJSON('/authenticated/services/recordCount', displayPagination, onError);
}

//Build the Pagination
function displayPagination(count) {
    numPages = Math.ceil(count/recordsPerPage);
    for (var i = 0; i<numPages; i++) {
    	$('#nextButton').before("<li id='page" + (i + 1) + "'><a href='#' onclick='changePage(" + (i + 1) + ");'>" + (i+1) + "</a></li>");
    }
    $('#previousButton').next().addClass('active');
}

function changePage(page) {
	if (page == currentPage) {
		return;
	}
	clearIntelList();
	getIntelList(((page - 1) * recordsPerPage), recordsPerPage);
	$('li.active').removeClass('active');
	$('#page' + page).addClass('active');
	currentPage = page;
}

function nextPage() {
	if (currentPage + 1 > numPages) {
		return;
	} 
	else {
		changePage(currentPage + 1);
	}
}

function previousPage() {
	if (currentPage - 1 < 1) {
		return;
	} 
	else {
		changePage(currentPage - 1);
	}
}

//Shows the Email Modal Dialog
function showEmailDialog(id) {
	$('#emailItemModal').attr('data-id-to-email', id);
	$('#emailItemModal').modal('show');
	$('#emailTo').focus();
}

//Completes the emailing of the item
function emailItem() {
	var data = new Object();
	data.id = $('#emailItemModal').attr('data-id-to-email');
	data.to = $('#emailTo').val();
	$('#emailTo').val('');
	$.post('/authenticated/services/emailIntelItem', data, emailComplete);
	$('#emailItemModal').modal('hide');
}

function emailComplete(data) {
	if (data != "Success") {
		alert(data.toString());
	}
	else {
		$('#modalHeader').html('Email Sent');
		$('#modalBody').html('The Email was sent successfuly');
		$('#myModal').modal('show');
	}
}

//Global error handling
function onError(error) {
    if (debugging) {
        alert(error.toString());
    }
}
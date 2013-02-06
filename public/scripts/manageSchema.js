$(document).ready(initialize);

var debugging = true;

function initialize() {
	getSchemaList();
}

//Gets a list of schema items to populate the side nav
function getSchemaList() {
	$.getJSON('/authenticated/services/schemaList', buildNavigation, onError);
}

function buildNavigation(list) {
	//Clear the list
	$('#leftNavigation').html('');
	//Add the schemaList header
	$('#leftNavigation').append("<li class='nav-header'>Schema Items (click to edit)</li>");
    if (list != null) {
    	for (var i = 0; i < list.length; i++) {
    		$('#leftNavigation').append("<li id='" + list[i].field_name + "'><a href='#' onclick='loadSchemaItem(\"" + list[i].field_name + "\")'>" + list[i].field_name + "</a></li>")
    	}
    }
}

function loadSchemaItem(field_name) {
	$.getJSON('/authenticated/services/schemaItem/' + field_name, showSchemaItem, onError);
}

function showSchemaItem(item) {
	$('#leftNavigation').children().removeClass('active');
	$('#' + item.field_name).addClass('active');
	$('#txtFieldName').val(item.field_name);
	$('#txtDisplayName').val(item.display_name);
	$('#txtDescription').val(item.description);
	$('#txtAddedBy').val(item.added_by);
	$('#txtValidationExpression').val(item.validation_expression);
	$('#checkRequired').prop('checked', item.validation_required.toString().toLowerCase() == 'true');
	$('#checkDefault').prop('checked', item.default_field != null && item.default_field.toString().toLowerCase() == 'true');
	$('#txtFieldName').focus();
}

//submits the form asynchronously
function submitFormAjax() {
	var data = new Object();
	data.txtFieldName = $('#txtFieldName').val();
	data.txtDisplayName = $('#txtDisplayName').val();
	data.txtDescription = $('#txtDescription').val();
	data.txtAddedBy = $('#txtAddedBy').val();
	data.txtValidationExpression = $('#txtValidationExpression').val();
	data.checkRequired = $('#checkRequired:checked').length > 0;
	data.checkDefault = $('#checkDefault:checked').length > 0;
	$.post('/authenticated/manage-schema', data, submitComplete);
	//alert('Posted');
}

function clearForm() {
	$('#leftNavigation').children('li').removeClass('active');
	$('#txtFieldName').val('');
	$('#txtDisplayName').val('');
	$('#txtDescription').val('');
	$('#txtAddedBy').val('');
	$('#txtValidationExpression').val('');
	$('#checkRequired').prop('checked', false);
	$('#checkDefault').prop('checked', false);
	$('#txtFieldName').focus();
}

function submitComplete(results) {
	if (results == "Success") {
		//window.location = '/authenticated/manage-schema';
		clearForm();
		//Show the alert that the post was successful and scroll to the top of the page
		$('#successAlert').show();
		$(window).scrollTop(0);
		//Refresh the list with the new schema item
		getSchemaList();
		$('#txtFieldName').focus();
	}
	else {
		alert(results.toString());
	}
}

//Global error handling
function onError(error) {
    if (debugging) {
        alert(error.toString());
    }
}
/*
 Intel-DB: unstructured structure for intelligence analysis
 Copyright (C) 2012-2013 Ryan M. Victory

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with this program.  If not, see [http://www.gnu.org/licenses/].
 */
$(document).ready(initialize);

var debugging = true;

function initialize() {
	$('#date_added').val(new Date().toUTCString());
	$('#date_expires').focus();
	getNewFieldsList();
	$('#leftWell').append('Use this page to add new pieces of intelligence to the database. Remember that you can specify more fields using the Manage Schema tab above.');
	$('#leftWell').append($('#fileUploadTemplate').html());
}

//submits the form asynchronously
function submitFormAjax() {
	var data = new Object();
	var inputFields = $('input, textarea');
	for (var i = 0; i < inputFields.length; i++) {
		if (!isFieldValid(inputFields[i])) {
			$('#validationError').show();
			return;
		}
		data[$(inputFields[i]).attr('id')] = $(inputFields[i]).val();
	}
	data.category = $('#category').val();
	data.level = $('#level').val();
	$.post('/authenticated/add-data', data, submitComplete);
	//alert('Posted');
}

function validateFieldOnBlur(field) {
	$(field).parents('.control-group').removeClass('error');
	if (!isFieldValid(field)) {
		$(field).parents('.control-group').addClass('error');
	}
}

function isFieldValid(field) {
	var text = $(field).val();
	var validationRequired = $(field).attr('data-validation-required');
	var validationExpression = $(field).attr('data-validation-expression');
	
	//If we don't know if validation is required or if we see it's not, return that the field is valid
	if (validationRequired == null || validationRequired.match(/false/i)) {
		return true;
	}
	
	//If we don't have a validationExpression then Return true for being valid
	if (validationExpression == null || validationExpression == '') {
		return true;
	}
	
	//If the field is blank, return that it's valid
	if (text == null || text == '') {
		return true;
	}
	
	//At this point, validation should take place
	var regex = new RegExp(validationExpression);
	return regex.test(text);
	
}

function submitComplete(results) {
	if (results == "Success") {
		window.location = '/authenticated/index';
	}
	else {
		alert(results.toString());
	}
}

function getNewFieldsList() {
	$.getJSON('/authenticated/services/schemaList', displayNewFieldsList, onError);
}

function displayNewFieldsList(fields) {
	$('#selectNewField').append('<option></option>');
	for (var i = 0; i < fields.length; i++) {
		if (shouldFieldDisplay(fields[i].field_name)) {
			$('#selectNewField').append("<option value='" + fields[i].field_name + "'>" + fields[i].display_name + "</option>");
		}
	}
}

//Determines if a field should be displayed in the new field dropdown (the default fields shouldn't be displayed)
function shouldFieldDisplay(field) {
	var nondisplay = ['date_added', 'source_individual', 'source_institution', 'title', 'category', 'tags', 'context', 'date_expires'];
	for (var i = 0; i < nondisplay.length; i++) {
		if (field == nondisplay[i]) {
			return false;
		}
	}
	return true;
}

function addFieldSelected() {
	$.getJSON('/authenticated/services/schemaItem/' + $('#selectNewField').val(), completeAddField, onError);
}

function completeAddField(field) {
	$('#insertNewField').before($('#fieldTemplate').render(field));
	$('#' + field.field_name).focus();
	$('#selectNewField').val(0);
}

//Global error handling
function onError(error) {
    if (debugging) {
        alert(error.toString());
    }
}

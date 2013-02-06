$(document).ready(initialize);

function initialize() {
	$('#leftWell').append($('#wellTemplate').html());
	getTemplateList();
	getSchemaList();
}

function getRuleResults() {
	var data = new Object();
	data.rule = $('#txtAdHocRule').val();
	$.post('/authenticated/services/runRule', data, displayResults, "json");
	return false;
}

function getTemplateList() {
	$.getJSON('/authenticated/services/exportTemplateList', buildTemplateList);
}

function buildTemplateList(list) {
	$('.templateItem').remove();
	for (var i = 0; i < list.length; i++) {
		$('#blankOption').after("<option value='" + list[i].name + "' class='templateItem'>" + list[i].title + "</option>");
	}
}

function getSchemaList() {
	$.getJSON('/authenticated/services/schemaList', buildFieldList);
}

function buildFieldList(list) {
	for (var i = 0; i < list.length; i++) {
    		$('#fields').append("<li><a class='needsTooltip' href='#' rel='tooltip' title='" + list[i].description + "'>" + list[i].field_name + "</a></li>")
    }
    $('.needsTooltip').tooltip();
}

function displayResults(results) {
	$('#results').html('');
	for(var i = 0; i<results.length; i++) {
		$('#results').append(results[i].toString() + "<br>");
	}
}

function savedTemplateChanged() {
	var selectedItem =$('#selectSavedTemplate option:selected').text();
	if (selectedItem == 'Create New Template...') {
		$('#templateModal').modal('show');
		$('#selectSavedTemplate').val(0);
	}
	else if (selectedItem != '') {
		$.getJSON('/authenticated/services/getTemplate/' + $('#selectSavedTemplate option:selected').attr('value'), displayRule);
	}
	else {
		$('#txtAdHocRule').val('');
	}
}

function displayRule(rule) {
	$('#txtAdHocRule').val(rule.template);
}

function saveNewTemplate() {
	var data = new Object();
	data.title = $('#txtTemplateName').val();
	data.template = $('#txtTemplate').val();
	$.post('/authenticated/services/saveExportTemplate', data, getTemplateList);
	$('#templateModal').modal('hide');
}

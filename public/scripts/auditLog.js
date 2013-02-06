$(document).ready(initialize);

function initialize() {
	loadData();
	$('#leftWell').append('<p>The audit log provides basic information about logins and failed logins to the application. Please refer to the documentation for more information.</p>');
}

function loadData() {
	$.getJSON('/authenticated/log/100/0', displayData, onError);
}

function displayData(data) {
	$('#auditTable').append($('#rowTemplate').render(data));
}

//Global error handling
function onError(error) {
    if (debugging) {
        alert(error.toString());
    }
}
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
---
layout: page
title: Upcoming Events
permalink: /events
---

The following events are currently scheduled.


## Troop Calendars

<style>
.calendar-tabs {
	max-width: 800px;
}

.calendar-tab-buttons {
	display: flex;
	gap: 8px;
	margin-bottom: 10px;
}

.calendar-tab-button {
	border: 1px solid #cccccc;
	border-radius: 6px 6px 0 0;
	background: #f5f5f5;
	color: #222222;
	padding: 8px 14px;
	font-weight: 600;
	cursor: pointer;
}

.calendar-tab-button.active {
	background: #ffffff;
	border-bottom-color: #ffffff;
}

.calendar-tab-panels {
	border: 1px solid #cccccc;
	border-radius: 0 6px 6px 6px;
	background: #ffffff;
	padding: 8px;
}

.calendar-tab-panel {
	display: none;
}

.calendar-tab-panel.active {
	display: block;
}

.calendar-embed {
	border: 0;
	width: 100%;
	height: 600px;
}

.events-panel {
	padding: 8px 8px 12px 8px;
}

.upcoming-events-list {
	margin: 0 0 14px 0;
	padding-left: 20px;
}

.events-subheading {
	margin: 4px 0 8px 0;
}

.expandable-events {
	list-style: none;
	margin: 0 0 14px 0;
	padding-left: 0;
}

.event-details {
	border: 1px solid #e2e2e2;
	border-radius: 6px;
	margin-bottom: 8px;
	padding: 6px 10px;
	background: #fafafa;
}

.event-details summary {
	cursor: pointer;
	font-weight: 600;
}

.event-detail-body {
	margin-top: 8px;
	padding-left: 8px;
}

.event-detail-body p {
	margin: 0 0 6px 0;
}

.events-current-as-of {
	font-size: 0.95em;
	color: #555555;
	margin: 0 0 10px 0;
}
</style>

<div class="calendar-tabs">
	<div class="calendar-tab-buttons" role="tablist" aria-label="Troop calendar options">
		<button id="tab-old" class="calendar-tab-button active" role="tab" aria-controls="panel-old" aria-selected="true" data-target="panel-old">Old (Google)</button>
		<button id="tab-new" class="calendar-tab-button" role="tab" aria-controls="panel-new" aria-selected="false" data-target="panel-new">New (Scoutbook)</button>
	</div>

	<div class="calendar-tab-panels">
		<div id="panel-old" class="calendar-tab-panel active events-panel" role="tabpanel" aria-labelledby="tab-old">
			<h3 class="events-subheading">Current Upcoming Events</h3>
			<ul class="upcoming-events-list">
				<li>4/6: Troop Meeting & Summer Camp meeting! 6:40pm</li>
				<li>4/10 - 4/12: ILST/Advancement Campout
					<ul>
						<li>Meet at 5:30pm at the Church wearing Class As. Come having eaten dinner. Expect to return around 10am on Sunday.</li>
					</ul>
				</li>
				<li>4/13: Troop Meeting</li>
				<li>4/18: Swim Test - noon-2pm</li>
				<li>4/18: Elizabeth Eagle CoH - 4:30pm-6pm</li>
				<li>4/20: Court of Honor</li>
				<li>4/26: Flag Ceremony at Special Olympics - 9am-10am</li>
				<li>4/27: Troop Meeting</li>
				<li>4/29: PLC @ Solon Library</li>
				<li>5/2: Trash the Trash in Solon (9am-noon)</li>
				<li>5/2: Archeology MB at Dover Dam Weekend (all day)</li>
				<li>5/2: Swim Test - noon-2pm</li>
				<li>5/3: Semi-Annual Planning</li>
				<li>5/4: Troop Meeting</li>
				<li>5/8 - 5/9: MBU at Firelands</li>
				<li>5/11: Troop Meeting</li>
				<li>5/18: Troop Meeting</li>
				<li>5/25: NO Troop Meeting</li>
				<li>5/27: PLC</li>
				<li>6/8: First Troop Meeting at Shelterhouse - 6:30pm - 8pm</li>
				<li>6/28/26 - 7/4/26: Summer Camp</li>
				<li>7/22/26 - 7/31/26: National Jamboree</li>
				<li>8/31: Court of Honor - last meeting at Shelterhouse</li>
				<li>9/7: First Troop Meeting at Church</li>
			</ul>

			<h3 class="events-subheading">Current Calendar</h3>
			<iframe class="calendar-embed" src="https://calendar.google.com/calendar/embed?src=ccb15b7c3c3e506c128bcabfb6b42037342f0d1b73f8e493120475e07f119d07%40group.calendar.google.com&ctz=America%2FNew_York" frameborder="0" scrolling="no"></iframe>
		</div>

		<div id="panel-new" class="calendar-tab-panel events-panel" role="tabpanel" aria-labelledby="tab-new">
			<h3 class="events-subheading">Scoutbook Upcoming Events (Listed)</h3>
			{% assign scoutbook_data = site.data['scoutbook-events'] %}
			{% if scoutbook_data and scoutbook_data.events and scoutbook_data.events.size > 0 %}
			{% if scoutbook_data.currentAsOf %}
			<p class="events-current-as-of">{{ scoutbook_data.currentAsOf }}</p>
			{% endif %}
			<ul class="expandable-events" id="scoutbook-upcoming-events">
				{% for event in scoutbook_data.events %}
				<li class="event-details">
					<details>
						<summary>{{ event.display }}</summary>
						<div class="event-detail-body">
							<p><strong>Title:</strong> {{ event.title }}</p>
							<p><strong>Start:</strong> {{ event.start }}</p>
							<p><strong>End:</strong> {{ event.end }}</p>
							<p><strong>All day:</strong> {% if event.allDay %}Yes{% else %}No{% endif %}</p>
							{% if event.location and event.location != "Location was not specified" and event.location != "None" %}
							<p><strong>Location:</strong> {{ event.location }}</p>
							{% endif %}
							{% if event.description %}
							<p><strong>Description:</strong><br>{{ event.description | escape | newline_to_br }}</p>
							{% endif %}
							{% if event.url %}
							<p><a href="{{ event.url }}" target="_blank" rel="noopener">View event details</a></p>
							{% endif %}
						</div>
					</details>
				</li>
				{% endfor %}
			</ul>
			{% else %}
			<ul class="upcoming-events-list" id="scoutbook-upcoming-events">
				<li>No parsed Scoutbook events found. Run scripts/utils/parse-scoutbook-ical.ps1 to refresh.</li>
			</ul>
			{% endif %}

			<h3 class="events-subheading">Scoutbook Replacement Calendar</h3>
			<iframe class="calendar-embed" src="https://calendar.google.com/calendar/embed?src=cbbv71vp4m9r39h6uttca3himb0sk5cr%40import.calendar.google.com&ctz=America%2FDetroit" frameborder="0" scrolling="no"></iframe>

			<h3 class="events-subheading">Subscribe to Scoutbook iCal</h3>
			<p><strong>iCal URL:</strong> <a href="https://api.scouting.org/advancements/events/calendar/126388" target="_blank" rel="noopener">https://api.scouting.org/advancements/events/calendar/126388</a></p>
			<p><strong>webcal URL:</strong> <a href="webcal://api.scouting.org/advancements/events/calendar/126388" target="_blank" rel="noopener">webcal://api.scouting.org/advancements/events/calendar/126388</a></p>
			<ul class="upcoming-events-list">
				<li><strong>Google Calendar:</strong> In the left sidebar, select Other calendars, click +, choose From URL, and paste the iCal URL.</li>
				<li><strong>Apple Calendar (macOS):</strong> File, New Calendar Subscription, paste the webcal URL, then choose update frequency.</li>
				<li><strong>Apple Calendar (iPhone/iPad):</strong> Settings, Apps, Calendar, Calendar Accounts, Add Account, Other, Add Subscribed Calendar, then paste the iCal URL.</li>
				<li><strong>Outlook on the web:</strong> Add calendar, Subscribe from web, paste the iCal URL, and save.</li>
			</ul>
		</div>
	</div>
</div>

<script>
	(function () {
		var tabButtons = document.querySelectorAll('.calendar-tab-button');
		var tabPanels = document.querySelectorAll('.calendar-tab-panel');

		function showPanel(targetPanelId) {
			tabButtons.forEach(function (button) {
				var isActive = button.getAttribute('data-target') === targetPanelId;
				button.classList.toggle('active', isActive);
				button.setAttribute('aria-selected', isActive ? 'true' : 'false');
			});

			tabPanels.forEach(function (panel) {
				panel.classList.toggle('active', panel.id === targetPanelId);
			});
		}

		tabButtons.forEach(function (button) {
			button.addEventListener('click', function () {
				showPanel(button.getAttribute('data-target'));
			});
		});
	})();
</script>

If you do not have access to the calendar, please contact us.
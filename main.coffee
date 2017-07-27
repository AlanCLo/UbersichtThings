# Dashboard for my Trello
# ====
# Pull data from Trello to visualise on my desktop.
#
# Dependencies
# * Trello API setup
# * jq installed


# You need to save your Trello API settings in
#   ~/TrelloAPI.env.sh
# with the following contents
#   export TRELLO_APP_KEY=...
#   export TRELLO_TOKEN=...
#   export TRELLO_BOARD_ID=...




# ----
# Variables
# ----

refreshFrequency: 3600000 # Refresh every hour
trelloDoneListId: "569ed04150080cd5968c4d98" # Id of a done list which don't be processed


# ----
# Constants
# ----

MSEC_IN_DAY: 24 * 60 * 60 * 1000
DAY_NAMES: ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
OFFDAY_INDICIES:[0,6] # Sat and Sun are off days. Colour them differently

# Fetch all the cards from a board, then convert them into an an array of objects with {Name, Due, ID}
command: """
$(cat ~/TrelloAPI.env.sh)
curl --silent "https://api.trello.com/1/boards/${TRELLO_BOARD_ID}/cards?key=${TRELLO_APP_KEY}&token=${TRELLO_TOKEN}" | \
/usr/local/bin/jq '[.[] | select(.due != null) | {name:.name, due:.due, idList:.idList}] | sort_by(.due)'
"""


style: """
	color: rgba(#fff, 0.9)
	font-family Helvetica Neue

	.layout
		width: 100%

	.column1
		float: left
		max-width: 400px

	.column2
		float: left
		margin-left: 400px
		max-width: 400px

	.column3
		float: left
		margin-left: 800px
		max-width: 400px

	.container
		background rgba(#000, .5)
		margin 20px 20px 15px
		padding 10px
		border-radius 5px
	
	.title
		font-size: 14px
		font-weight: 500
		padding-bottom: 5px
		text-transform: uppercase	
	

	table
		border-collapse: collapse
		
	td
		padding: 4px 4px 4px 4px
		text-align: left
		font-size: 11px
	
	.day
		text-align: right
		background: rgba(#fff, 0.1)
		
	.off
		background: rgba(#aaf, 0.2)
			
	.midline
		padding-left: 0px
		padding-right: 0px
		width: 1px
		background: rgba(#0af, 0.8)
		
	.content
		font-size: 16px
		font-weight: bold

	.today
		background: rgba(#afa, 0.2)
		
"""

render: -> """
	<div class="layout">
			<div class="container column1" id="thisMonth">
				<div class="title"></div>
				<table></table>
			</div>
			<div class="container column2" id="nextMonth">
				<div class="title"></div>
				<table></table>
			</div>
			<div class="container column3" id="beyond">
				<div class="title"></div>
				<table></table>
			</div>
	</div>
"""


# ----
# Update
# ----

update: (output, domEl) ->
	cards = JSON.parse(output)

	drawTable = (uber, cards, domEl, containerId, title, isThisMonth) ->
		$titleDiv = $(domEl).find(containerId).find("div.title")
		$titleDiv.empty()
		$titleDiv.append(title)
		$dailyList = $(domEl).find(containerId).find("table")
		$dailyList.empty()

		now = new Date()
		if !isThisMonth
			now.setMonth(now.getMonth() + 1)
		y = now.getFullYear()
		m = now.getMonth()
		today = now.getDate()

		if isThisMonth
			i = today
		else
			i = 1
		w = new Date(y, m, i).getDay()
		lastDate = new Date(y, m + 1, 0).getDate()

		while i <= lastDate
			w %= 7
			isToday = (i is today) and isThisMonth
			todayClass = "today"
			if !isToday
				todayClass = ""
			isOffday = (uber.OFFDAY_INDICIES.indexOf(w) isnt -1)
			offDayClass = "off"
			if !isOffday
				offDayClass = ""
		
			dayText = uber.DAY_NAMES[w]

			num = 0
			for cardData in cards
				if cardData.idList == uber.trelloDoneListId
					continue
				cardDate = new Date(cardData.due)
				if cardDate.getFullYear() == y and cardDate.getMonth() == m and cardDate.getDate() == i
					html = "<tr>"
					if num == 0
						html += """<td class="day #{offDayClass}">#{dayText} #{i}</td>"""
					else
						html += """<td class="day #{offDayClass}"></td>"""

					html += """<td class="midline"></td>"""
					html += """<td class="content #{todayClass}">#{cardData.name}</td>"""

					html += "</tr>"
					$dailyList.append(html)
					num++
		
			if num == 0
				$dailyList.append("""
					<tr>
						<td class="day #{offDayClass}">#{dayText} #{i}</td>
						<td class="midline"></td>
						<td class="content #{todayClass}"></td>
					</tr>
				""")
			i++
			w++

	drawBeyond = (uber, cards, domEl, containerId, title) ->
		$titleDiv = $(domEl).find(containerId).find("div.title")
		$titleDiv.empty()
		$titleDiv.append(title)
		$beyondTable = $(domEl).find(containerId).find("table")
		$beyondTable.empty()

		now = new Date()
		next = new Date()
		next.setMonth(next.getMonth() + 1)
		daysDiff = (d1, d2) -> Math.round((d2 - d1)/uber.MSEC_IN_DAY)

		for cardData in cards
			if cardData.idList == uber.trelloDoneListId
				continue
			cardDate = new Date(cardData.due)
			if cardDate > next
				html = "<tr>"
				html += "<td>#{cardDate.toISOString().substring(0,10)}</td>"
				diff = daysDiff(now, cardDate)
				html += "<td>(#{diff} DAYS)</td>"
				html += """<td class="content">#{cardData.name}</td></tr>"""
				html += "</tr>"
				$beyondTable.append(html)


	drawTable(@, cards, domEl, "#thisMonth", "This Month", true)
	drawTable(@, cards, domEl, "#nextMonth", "Next Month", false)
	drawBeyond(@, cards, domEl, "#beyond", "Beyond")
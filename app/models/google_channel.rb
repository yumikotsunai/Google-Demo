class GoogleChannel < ActiveRecord::Base

    # チャネル更新（1週間以内に定期実行）
    def update
        # ここに処理を記述
        googleAccountId = APP_CONFIG["google"]["user_name"]
        clientId = GoogleAccount.find_by(account_id: googleAccountId).client_id
        clientSecret = GoogleAccount.find_by(account_id: googleAccountId).client_secret
        refreshToken = GoogleToken.find_by(account_id: googleAccountId).refresh_token
        #refreshToken = "1/pdYsrCvJ5_WnjQDtDGajZMuSQFSh5-DohNH5qtXMrCM"
        calendarId = GoogleAccount.find_by(account_id: googleAccountId).calendar_id
        
    	  #GoogleApiを利用する
    	  client = Google::APIClient.new
        client.authorization.client_id = clientId
        client.authorization.client_secret = clientSecret
        client.authorization.refresh_token = refreshToken
        client.authorization.fetch_access_token!
        
        service = client.discovered_api('calendar', 'v3')
        
        res = client.execute!(
          api_method: service.events.watch,
          parameters: { calendarId: calendarId },
          body_object: {
            id: SecureRandom.uuid(),
            type: 'web_hook',
            address: URI.encode(APP_CONFIG["webhost"]+'notifications/callback')
          }
        )
    	  
    	@status = res.status
    	
    	if res.status.to_s == "200"
    	    puts("チャネル作成に成功")
    	    puts(res.body)
          @status = "認証に成功しました"
            
          #カレンダーIDが含まれているURIを取得.以下は取得例
          #"https://www.googleapis.com/calendar/v3/calendars/i8a77r26f9pu967g3pqpubv0ng@group.calendar.google.com/events?maxResults=250&alt=json"
          j = ActiveSupport::JSON.decode( res.body )
          resourceUri = j["resourceUri"]
          
          #GoogleのカレンダーIDをキーにしてGoogleChannelのDBを検索
      	  gCalendarId = nil
      	  id = nil
      	  if GoogleChannel.find_by(calendar_id: calendarId) != nil
      	    gCalendarId = GoogleChannel.find_by(calendar_id: calendarId).calendar_id
      	    id = GoogleChannel.find_by(calendar_id: calendarId).id
      	  end 
      	  debugger
        	 
        	if gCalendarId == nil
            #チャネルのIDと、カレンダーIDの対応を新規保存
            self.channel_id = j["id"]
          	self.calendar_id = calendarId
          	self.access_token = ""
          	self.refresh_token = refreshToken
          	self.expires_in = DateTime.now + 7.day
          	#self.status = 1
          	self.resource_id = j["resourceId"]
          	debugger
          	self.save
        	else
        	  #更新
        	  debugger
        	  gChannel = GoogleChannel.find(id)
        	  gChannel.update_attributes(:channel_id => j["id"], :refresh_token => refreshToken, :expires_in => DateTime.now + 7.day, :resource_id => j["resourceId"])
        	  
        	  #GoogleToken.update(id, :access_token => j["access_token"], :refresh_token => j["refresh_token"], :expire => Time.now + j["expires_in"].second)
        	  
        	end
        else
    	  @status = "認証に失敗しました"
    	    #self.status = 0
          puts @status
          puts self
          puts res
    	end
    	
    	return @status
    end
    
    
    #チャネル削除
    def delete
        
        #アカウントIDに紐付くカレンダーIDから、channelIdとresourceIdを取得
        calendarId = GoogleAccount.find_by(account_id: APP_CONFIG["google"]["user_name"]).calendar_id
        channelId = GoogleChannel.find_by(calendar_id: calendarId).channel_id
        resourceId = GoogleChannel.find_by(calendar_id: calendarId).resource_id
        accessToken = GoogleToken.find_by(account_id: APP_CONFIG["google"]["user_name"]).access_token
        
        postbody = {
          "id": channelId,
          "resourceId": resourceId,
        }
        
        auth = "Bearer " + accessToken
        res = HTTP.headers("Content-Type" => "application/json",:Authorization => auth)
        .post("https://www.googleapis.com/calendar/v3/channels/stop", :ssl_context => CTX , :body => postbody.to_json)
        
        puts("channel削除")
        puts(res.code)
    end
    
end

# == Schema Information
#
# Table name: google_channels
#
#  channel_id       :string
#  calendar_id      :string
#  expires_in       :datetime
#  created_at       :datetime
#  updated_at       :datetime

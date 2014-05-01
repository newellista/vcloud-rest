require 'pry'

module VCloudClient
  class Connection
    ## Enable/Disable an organization
    #
    def enable_organization(organization_id, bEnabled = true)
      params = {
        'method' => :post,
        'command' => "/admin/org/#{organization_id}/action/#{ bEnabled ? 'enable' : 'disable'}"
      }

      send_request(params)
    end

    ## Create an organization
    #
    def create_organization(org_name, org_description, org_fullname)
      params = {
        'method' => :post,
        'command' => '/admin/orgs'
      }

      builder = Nokogiri::XML::Builder.new do |xml|
      xml.AdminOrg(
        "xmlns" => "http://www.vmware.com/vcloud/v1.5",
        "name" => org_name,
        "type" => "application/vnd.vmware.admin.organization+xml") {
        xml.Description org_description
        xml.FullName org_fullname
        xml.Settings {
          xml.OrgGeneralSettings {
            xml.CanPublishCatalogs 'false'
            xml.CanPublishExternally 'false'
            xml.CanSubscribe 'true'
            xml.DeployedVMQuota '0'
            xml.StoredVmQuota '0'
            xml.UseServerBootSequence 'false'
            xml.DelayAfterPowerOnSeconds '0'
          }
          xml.OrgLdapSettings {
            xml.OrgLdapMode 'SYSTEM'
            xml.CustomUsersOu
          }
          xml.OrgEmailSettings {
            xml.IsDefaultSmtpServer 'true'
            xml.IsDefaultOrgEmail 'true'
            xml.FromEmailAddress
            xml.DefaultSubjectPrefix
            xml.IsAlertEmailToAllAdmins 'true'
          }
        }
      }
      end

      response, headers = send_request(params, builder.to_xml, "application/vnd.vmware.admin.organization+xml")

      ##
      # TODO: Parse response and return Organization ID
      ##

      id_urn = response.css("AdminOrg").attribute("id")

      id_urn.to_s.split(':').last

    end

    ##
    # Create a Local User
    def create_organization_admin(organization_id, full_name, email, username, password, role)
      params = {
        'method' => :post,
        'command' => "/admin/org/#{organization_id}/users"
      }

      builder = Nokogiri::XML::Builder.new do |xml|
      xml.User(
        "xmlns" => "http://www.vmware.com/vcloud/v1.5",
        "name" => "#{username}") {
          xml.FullName full_name
          xml.EmailAddress email
          xml.IsEnabled true
          xml.Role role
          xml.Password password
          xml.GroupReferences
        }
      end

      response, headers = send_request(params, builder.to_xml, "application/vnd.vmware.admin.user+xml")
    end

    ##
    # Fetch existing organizations and their IDs
    def get_organizations
      params = {
        'method' => :get,
        'command' => '/org'
      }

      response, headers = send_request(params)

      orgs = response.css('OrgList Org')

      results = {}
      orgs.each do |org|
        results[org['name']] = org['href'].gsub(/.*\/org\//, "")
      end
      results
    end

    ##
    # friendly helper method to fetch an Organization Id by name
    # - name (this isn't case sensitive)
    def get_organization_id_by_name(name)
      result = nil

      # Fetch all organizations
      organizations = get_organizations()

      organizations.each do |organization|
        if organization[0].downcase == name.downcase
          result = organization[1]
        end
      end
      result
    end


    ##
    # friendly helper method to fetch an Organization by name
    # - name (this isn't case sensitive)
    def get_organization_by_name(name)
      result = nil

      # Fetch all organizations
      organizations = get_organizations()

      organizations.each do |organization|
        if organization[0].downcase == name.downcase
          result = get_organization(organization[1])
        end
      end
      result
    end

    ##
    # Fetch details about an organization:
    # - catalogs
    # - vdcs
    # - networks
    # - task lists
    def get_organization(orgId)
      params = {
        'method' => :get,
        'command' => "/org/#{orgId}"
      }

      response, headers = send_request(params)
      catalogs = {}
      response.css("Link[type='application/vnd.vmware.vcloud.catalog+xml']").each do |item|
        catalogs[item['name']] = item['href'].gsub(/.*\/catalog\//, "")
      end

      vdcs = {}
      response.css("Link[type='application/vnd.vmware.vcloud.vdc+xml']").each do |item|
        vdcs[item['name']] = item['href'].gsub(/.*\/vdc\//, "")
      end

      networks = {}
      response.css("Link[type='application/vnd.vmware.vcloud.orgNetwork+xml']").each do |item|
        networks[item['name']] = item['href'].gsub(/.*\/network\//, "")
      end

      tasklists = {}
      response.css("Link[type='application/vnd.vmware.vcloud.tasksList+xml']").each do |item|
        tasklists[item['name']] = item['href'].gsub(/.*\/tasksList\//, "")
      end

      { :catalogs => catalogs, :vdcs => vdcs, :networks => networks, :tasklists => tasklists }
    end

    ##
    # Fetch tasks from a given task list
    #
    # Note: id can be retrieved using get_organization
    def get_tasks_list(id)
      params = {
        'method' => :get,
        'command' => "/tasksList/#{id}"
      }

      response, headers = send_request(params)

      tasks = []

      response.css('Task').each do |task|
        id = task['href'].gsub(/.*\/task\//, "")
        operation = task['operationName']
        status = task['status']
        error = nil
        error = task.css('Error').first['message'] if task['status'] == 'error'
        start_time = task['startTime']
        end_time = task['endTime']
        user_canceled = task['cancelRequested'] == 'true'

        tasks << {
          :id => id,
          :operation => operation,
          :status => status,
          :error => error,
          :start_time => start_time,
          :end_time => end_time,
          :user_canceled => user_canceled
         }
      end
      tasks
    end

    ##
    # Cancel a given task
    #
    # The task will be marked for cancellation
    def cancel_task(id)
      params = {
        'method' => :post,
        'command' => "/task/#{id}/action/cancel"
      }

      # Nothing useful is returned here
      # If return code is 20x return true
      send_request(params)
      true
    end
  end
end

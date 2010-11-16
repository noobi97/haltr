module CompanyFilter

  unloadable

  def check_for_company
    Project.send(:include, ProjectHaltrPatch) #TODO: perque nomes funciona el primer cop sense aixo?
    if @project.company.nil?
      c = Company.new(:project=>@project)
      c.save(false)
      reload
    end
    unless @project.company.valid?
      flash[:error] = "Configure company settings before using haltr"
      redirect_to :controller => :companies, :action => :edit, :id => @project
    end
  end

end
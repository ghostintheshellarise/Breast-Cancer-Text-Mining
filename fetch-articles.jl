using Requests
using DataFrames
################################################################################
# this function returns a DataFrame of articles (pmid, title, abstract)
function fetchBreastCancerArticles(cancerType="breast cancer", researchType="diagnosis",
                                    minDate=1990,maxDate=2030, retmax=1000)

    search_terms = "\"$cancerType\"[TIAB] and \"$researchType\"[TIAB]"

    # Retrieve number of results - from ESearch results
    # define base search query for eutils
    base_search_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/esearch.fcgi"

    # run esearch to get pmids
    search_result = readstring(post(base_search_query;
    data = Dict("db" => "pubmed", "term" => "$search_terms", "retmax" => retmax,
                 "mindate"=>minDate, "maxdate"=>maxDate)))
    #print(search_result)

    # retrieve the pmids into an array
    pmids = []
    for result_line in split(search_result, "\n")
      # get list of pmids
      pmid = match(r"<Id>(\d+)<\/Id>", result_line)
      if pmid != nothing
        push!(pmids,pmid[1])
      end
    end

    # concatenate pmids into a single comma separated string
    id_string = join(collect(pmids), ",")

    # define base fetch query for eutils
    base_fetch_query = "https://eutils.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi"

    # retrieve metadata for pmid Set
    fetch_result = readstring(post(base_fetch_query; data = Dict("db" => "pubmed",
    "id" => id_string, "rettype" => "medline", "retmode" => "text")))

    # save metadata in a file
    output_file = open("output/$researchType.txt", "w")
    write(output_file,fetch_result)
    close(output_file)

    # field set
    pmid_array = [] # title set
    title_array = [] # title set
    abstract_array=[] # article abstract
    date_created_array=[] # Create Date (CRDT).
    # read through each line
    for fetch_article in split(fetch_result, "PMID- ")
        # clear all field
        pmid=""
        full_title=""
        full_abstract=""
        date_created=""

        # extract PMID
        pmid_str = match(r"([0-9]+)", fetch_article)
        if pmid_str != nothing
          pmid=pmid_str[1]
        end


        for fetch_line in split(fetch_article, "\n")
          # get Title
          title = match(r"TI  - ([\w\W \r\n]+)", fetch_line)
          if title != nothing
              full_title=title[1]
          end

          # get abstract
          abstract_str = match(r"AB  - ([\w\W \r\n]+)", fetch_line)
          if abstract_str != nothing
              full_abstract=abstract_str[1]
          end

          # date created
          date_created_str = match(r"CRDT- ([\w\W \r\n]+)", fetch_line)
          if date_created_str != nothing
              date_created=date_created_str[1]
          end
        end

        # push everything
        if pmid != ""
            push!(pmid_array, pmid)
            push!(title_array, full_title)
            push!(abstract_array, full_abstract)
            push!(date_created_array, date_created)
        end
    end

    # return dictionary of pmid and title
    df = DataFrame(pmid=pmid_array,
                    title=title_array,
                    date_created=date_created_array,
                    main_abstract=abstract_array
                    )

    return(df, fetch_result)

end

# usage
#df, output_text = fetchBreastCancerArticles("breast cancer", "prevention",2018,2018)

# ref
#https://www.nlm.nih.gov/bsd/mms/medlineelements.html#ab

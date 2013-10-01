psql -U paul -d ged -f closest-region.sql | sed -e 's/\"(//' | sed -e 's/)\"//' > closest-regions-all.csv

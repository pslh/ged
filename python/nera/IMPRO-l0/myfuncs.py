def run_query(query):
    my_mark = connection.cursor()
    my_mark.execute(query)
    my_mark.close()


def get_id(query):
    my_mark = connection.cursor()
    my_mark.execute(query)
    my_id = my_mark.fetchone()
    my_mark.close()
    if my_id is not None:
        return my_id[0]
    else:
        return None

def get_id_or_insert_first(query1, query2):
    my_mark = connection.cursor()
    my_mark.execute(query1)
    my_id = my_mark.fetchone()
    if my_id is not None:
        my_mark.close()
        return my_id[0]
    else:
        my_mark.execute(query2)
        my_mark.execute(query1)
        my_id = my_mark.fetchone()
        my_mark.close()
        if my_id is not None:
            return my_id[0]
        else:
           return None

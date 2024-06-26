CLASS lhc_zov_r_rap100_travel DEFINITION INHERITING FROM cl_abap_behavior_handler.
  PRIVATE SECTION.
    METHODS:
      get_global_authorizations FOR GLOBAL AUTHORIZATION
        IMPORTING
        REQUEST requested_authorizations FOR zov_r_rap100_travel
        RESULT result,
      earlynumbering_create FOR NUMBERING
        IMPORTING entities FOR CREATE zov_r_rap100_travel.
ENDCLASS.

CLASS lhc_zov_r_rap100_travel IMPLEMENTATION.
  METHOD get_global_authorizations.
  ENDMETHOD.
  METHOD earlynumbering_create.

    DATA:
      entity           TYPE STRUCTURE FOR CREATE zov_r_rap100_travel,
      travel_id_max    TYPE /dmo/travel_id,
      " change to abap_false if you get the ABAP Runtime error 'BEHAVIOR_ILLEGAL_STATEMENT'
      use_number_range TYPE abap_bool VALUE abap_false.

    "Ensure Travel ID is not set yet (idempotent)- must be checked when BO is draft-enabled
    LOOP AT entities INTO entity WHERE TravelID IS NOT INITIAL.
      APPEND CORRESPONDING #( entity ) TO mapped-zov_r_rap100_travel.
    ENDLOOP.

    DATA(entities_wo_travelid) = entities.
    "Remove the entries with an existing Travel ID
    DELETE entities_wo_travelid WHERE TravelID IS NOT INITIAL.

    IF use_number_range = abap_true.
      "Get numbers
      TRY.
          cl_numberrange_runtime=>number_get(
            EXPORTING
              nr_range_nr       = '01'
              object            = '/DMO/TRV_M'
              quantity          = CONV #( lines( entities_wo_travelid ) )
            IMPORTING
              number            = DATA(number_range_key)
              returncode        = DATA(number_range_return_code)
              returned_quantity = DATA(number_range_returned_quantity)
          ).
        CATCH cx_number_ranges INTO DATA(lx_number_ranges).

          LOOP AT entities_wo_travelid INTO entity.

            APPEND VALUE #(  %cid      = entity-%cid
                             %key      = entity-%key
                             %is_draft = entity-%is_draft
                             %msg      = lx_number_ranges
                          ) TO reported-zov_r_rap100_travel.
            APPEND VALUE #(  %cid      = entity-%cid
                             %key      = entity-%key
                             %is_draft = entity-%is_draft
                          ) TO failed-zov_r_rap100_travel.
          ENDLOOP.
          EXIT.
      ENDTRY.

      "determine the first free travel ID from the number range
      travel_id_max = number_range_key - number_range_returned_quantity.
    ELSE.
      "determine the first free travel ID without number range
      "Get max travel ID from active table
      SELECT SINGLE FROM zovrap100_travel FIELDS MAX( travel_id ) AS travelID INTO @travel_id_max.
      "Get max travel ID from draft table
      SELECT SINGLE FROM zovrap100_traved FIELDS MAX( travelid ) INTO @DATA(max_travelid_draft).
      IF max_travelid_draft > travel_id_max.
        travel_id_max = max_travelid_draft.
      ENDIF.

      "Set Travel ID for new instances w/o ID
      LOOP AT entities_wo_travelid INTO entity.
        travel_id_max += 1.
        entity-TravelID = travel_id_max.

        APPEND VALUE #( %cid      = entity-%cid
                        %key      = entity-%key
                        %is_draft = entity-%is_draft
                      ) TO mapped-zov_r_rap100_travel.
      ENDLOOP.


    ENDIF.


  ENDMETHOD.

ENDCLASS.

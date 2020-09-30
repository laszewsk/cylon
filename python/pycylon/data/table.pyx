##
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 # http://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 ##

from libcpp.string cimport string
from pycylon.common.status cimport _Status
from pycylon.common.status import Status
import uuid
from pycylon.common.join_config cimport CJoinType
from pycylon.common.join_config cimport CJoinAlgorithm
from pycylon.common.join_config cimport CJoinConfig
from pycylon.common.join_config import PJoinType
from pycylon.common.join_config import PJoinAlgorithm
from pyarrow.lib cimport CTable
from pyarrow.lib cimport pyarrow_unwrap_table
from pyarrow.lib cimport pyarrow_wrap_table
from libcpp.memory cimport shared_ptr

from pycylon.ctx.context cimport CCylonContextWrap
from pycylon.ctx.context import CylonContext

import pyarrow as pa
import numpy as np
import pandas as pd

import warnings

'''
TwisterX Table definition mapping 
'''

cdef extern from "../../../cpp/src/cylon/python/table_cython.h" namespace "cylon::python::table":
    cdef cppclass CxTable "cylon::python::table::CxTable":
        CxTable()
        CxTable(string)
        string get_id()
        int columns()
        int rows()
        void show()
        void show(int, int, int, int)
        _Status to_csv(const string)

        string join(CCylonContextWrap *ctx_wrap,const string, CJoinConfig)

        string distributed_join(CCylonContextWrap *ctx_wrap, const string &table_id, CJoinConfig join_config);

        string Union(CCylonContextWrap *ctx_wrap, const string &table_right);

        string DistributedUnion(CCylonContextWrap *ctx_wrap, const string &table_right);

        string Intersect(CCylonContextWrap *ctx_wrap, const string &table_right);

        string DistributedIntersect(CCylonContextWrap *ctx_wrap, const string &table_right);

        string Subtract(CCylonContextWrap *ctx_wrap, const string &table_right);

        string DistributedSubtract(CCylonContextWrap *ctx_wrap, const string &table_right);

        #string Project(const vector[int64_t]& project_columns);

cdef extern from "../../../cpp/src/cylon/python/table_cython.h" namespace "cylon::python::table::CxTable":
    cdef extern string from_pyarrow_table(CCylonContextWrap *ctx_wrap, shared_ptr[CTable] table)
    cdef extern shared_ptr[CTable] to_pyarrow_table(const string table_id)

cdef class Table:
    cdef CxTable *thisPtr
    cdef CJoinConfig *jcPtr
    cdef CCylonContextWrap *ctx_wrap

    def __cinit__(self, string id):
        '''
        Initializes the PyCylon Table
        :param id: unique id for the Table
        :return: None
        '''
        self.thisPtr = new CxTable(id)

    cdef __get_join_config(self, join_type: str, join_algorithm: str, left_column_index: int,
                           right_column_index: int):
        if left_column_index is None or right_column_index is None:
            raise Exception("Join Column index not provided")

        if join_algorithm is None:
            join_algorithm = PJoinAlgorithm.HASH.value

        if join_algorithm == PJoinAlgorithm.HASH.value:

            if join_type == PJoinType.INNER.value:
                self.jcPtr = new CJoinConfig(CJoinType.CINNER, left_column_index, right_column_index,
                                             CJoinAlgorithm.CHASH)
            elif join_type == PJoinType.LEFT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CLEFT, left_column_index, right_column_index,
                                             CJoinAlgorithm.CHASH)
            elif join_type == PJoinType.RIGHT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CRIGHT, left_column_index, right_column_index,
                                             CJoinAlgorithm.CHASH)
            elif join_type == PJoinType.OUTER.value:
                self.jcPtr = new CJoinConfig(CJoinType.COUTER, left_column_index, right_column_index,
                                             CJoinAlgorithm.CHASH)
            else:
                raise ValueError("Unsupported Join Type {}".format(join_type))

        elif join_algorithm == PJoinAlgorithm.SORT.value:

            if join_type == PJoinType.INNER.value:
                self.jcPtr = new CJoinConfig(CJoinType.CINNER, left_column_index, right_column_index,
                                             CJoinAlgorithm.CSORT)
            elif join_type == PJoinType.LEFT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CLEFT, left_column_index, right_column_index,
                                             CJoinAlgorithm.CSORT)
            elif join_type == PJoinType.RIGHT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CRIGHT, left_column_index, right_column_index,
                                             CJoinAlgorithm.CSORT)
            elif join_type == PJoinType.OUTER.value:
                self.jcPtr = new CJoinConfig(CJoinType.COUTER, left_column_index, right_column_index,
                                             CJoinAlgorithm.CSORT)
            else:
                raise ValueError("Unsupported Join Type {}".format(join_type))
        else:
            if join_type == PJoinType.INNER.value:
                self.jcPtr = new CJoinConfig(CJoinType.CINNER, left_column_index, right_column_index)
            elif join_type == PJoinType.LEFT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CLEFT, left_column_index, right_column_index)
            elif join_type == PJoinType.RIGHT.value:
                self.jcPtr = new CJoinConfig(CJoinType.CRIGHT, left_column_index, right_column_index)
            elif join_type == PJoinType.OUTER.value:
                self.jcPtr = new CJoinConfig(CJoinType.COUTER, left_column_index, right_column_index)
            else:
                raise ValueError("Unsupported Join Type {}".format(join_type))

    @property
    def id(self) -> str:
        '''
        Table Id is extracted from the Cylon C++ API
        :return: table id
        '''
        return self.thisPtr.get_id().decode()

    @property
    def columns(self) -> int:
        '''
        Column count is extracted from the Cylon C++ Table API
        :return: number of columns in PyCylon table
        '''
        return self.thisPtr.columns()

    @property
    def rows(self) -> int:
        '''
        Rows count is extracted from the Cylon C++ Table API
        :return: number of rows in PyCylon table
        '''
        return self.thisPtr.rows()

    def show(self):
        '''
        prints the table in console from the TwisterX C++ Table API
        :return: None
        '''
        self.thisPtr.show()

    def show_by_range(self, row1: int, row2: int, col1: int, col2: int):
        '''
        prints the table in console from the Cylon C++ Table API
        uses row range and column range
        :param row1: starting row number as int
        :param row2: ending row number as int
        :param col1: starting column number as int
        :param col2: ending column number as int
        :return: None
        '''
        self.thisPtr.show(row1, row2, col1, col2)

    def to_csv(self, path: str) -> Status:
        '''
        writes a PyCylon table to CSV file
        :param path: passed as a str, the path of the csv file
        :return: Status of the process (SUCCESS or FAILURE)
        '''
        cdef _Status status = self.thisPtr.to_csv(path.encode())
        s = Status(status.get_code(), b"", -1)
        return s

    def join(self, ctx: CylonContext, table: Table, join_type: str, algorithm: str, left_col: int, right_col: int) -> Table:
        '''
        Joins two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :param join_type: Join Type as str ["inner", "left", "right", "outer"]
        :param algorithm: Join Algorithm as str ["hash", "sort"]
        :param left_col: Join column of the left table as int
        :param right_col: Join column of the right table as int
        :return: Joined PyCylon table
        '''
        self.__get_join_config(join_type=join_type, join_algorithm=algorithm, left_column_index=left_col,
                               right_column_index=right_col)
        cdef CJoinConfig *jc1 = self.jcPtr        
        cdef string table_out_id = self.thisPtr.join(new CCylonContextWrap(ctx.get_config()), table.id.encode(), jc1[0])
        if table_out_id.size() == 0:
            raise Exception("Join Failed !!!")
        return Table(table_out_id)


    def distributed_join(self, ctx: CylonContext, table: Table, join_type: str, algorithm: str, left_col: int, right_col: int) -> Table:
        '''
        Joins two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :param join_type: Join Type as str ["inner", "left", "right", "outer"]
        :param algorithm: Join Algorithm as str ["hash", "sort"]
        :param left_col: Join column of the left table as int
        :param right_col: Join column of the right table as int
        :return: Joined PyCylon table
        '''
        self.__get_join_config(join_type=join_type, join_algorithm=algorithm, left_column_index=left_col,
                               right_column_index=right_col)
        cdef CJoinConfig *jc1 = self.jcPtr
        cdef string table_out_id = self.thisPtr.distributed_join(new CCylonContextWrap(ctx.get_config()), table.id.encode(), jc1[0])
        if table_out_id.size() == 0:
            raise Exception("Join Failed !!!")
        return Table(table_out_id)


    def union(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Union PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.Union(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Union Failed !!!")
        return Table(table_out_id)


    def distributed_union(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Union PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.DistributedUnion(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Distributed Union Failed !!!")
        return Table(table_out_id)

    def intersect(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Intersect PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.Intersect(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Intersect Failed !!!")
        return Table(table_out_id)


    def distributed_intersect(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Intersect PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.DistributedIntersect(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Distributed Union Failed !!!")
        return Table(table_out_id)

    def subtract(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Subtract PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.Subtract(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Subtract Failed !!!")
        return Table(table_out_id)


    def distributed_subtract(self, ctx: CylonContext, table: Table) -> Table:
        '''
        Union two PyCylon tables
        :param table: PyCylon table on which the join is performed (becomes the left table)
        :return: Subtract PyCylon table
        '''

        cdef string table_out_id = self.thisPtr.DistributedSubtract(new CCylonContextWrap(ctx.get_config()), table.id.encode())
        if table_out_id.size() == 0:
            raise Exception("Distributed Subtract Failed !!!")
        return Table(table_out_id)

    @staticmethod
    def from_arrow(obj, ctx: CylonContext) -> Table:
        '''
        creating a PyCylon table from PyArrow Table
        :param obj: PyArrow table
        :return: PyCylon table
        '''
        cdef shared_ptr[CTable] artb = pyarrow_unwrap_table(obj)
        cdef string table_id
        if artb.get() == NULL:
            raise TypeError("not an table")
        if ctx.get_config() == ''.encode():
            table_id = from_pyarrow_table(new CCylonContextWrap(''.encode()), artb)
        else:
            table_id = from_pyarrow_table(new CCylonContextWrap(ctx.get_config()), artb)
        return Table(table_id)

    # @staticmethod
    # def from_pandas(obj, ctx: CylonContext) -> Table:
    #     """
    #     creating a PyCylon table from Pandas DataFrame
    #     :param obj: Pandas DataFrame
    #     :rtype: PyCylon Table
    #     """
    #     table = pa.Table.from_pandas(obj)
    #     return Table.from_arrow(table, ctx)

    def to_arrow(self) -> pa.Table :
        '''
        creating PyArrow Table from PyCylon table
        :param self: PyCylon Table
        :return: PyArrow Table
        '''
        table = to_pyarrow_table(self.id.encode())
        py_arrow_table = pyarrow_wrap_table(table)
        return py_arrow_table

    def to_pandas(self) -> pd.DataFrame:
        """
        creating Pandas Dataframe from PyCylon Table
        :param self:
        :return: a Pandas DataFrame
        """
        table = to_pyarrow_table(self.id.encode())
        py_arrow_table = pyarrow_wrap_table(table)
        return py_arrow_table.to_pandas()


    def to_numpy(self, order='F') -> np.ndarray:
        """
        [Experimental]
        This method converts a Cylon Table to a 2D numpy array.
        In the conversion we stack each column in the Table and create a numpy array.
        For Heterogeneous Tables, use the generated array with Caution.
        :param order: numpy array order. 'F': Fortran Style F_Contiguous or 'C' C Style C_Contiguous
        :return: ndarray
        """
        table = to_pyarrow_table(self.id.encode())
        py_arrow_table = pyarrow_wrap_table(table)
        ar_lst = []
        _dtype = None
        for col in py_arrow_table.columns:
            npr = col.chunks[0].to_numpy()
            if None == _dtype:
                _dtype = npr.dtype
            if _dtype != npr.dtype:
                warnings.warn("Heterogeneous Cylon Table Detected!. Use Numpy operations with Caution.")
            ar_lst.append(npr)
        return np.array(ar_lst, order=order).T

    @property
    def column_names(self):
        table = to_pyarrow_table(self.id.encode())
        py_arrow_table = pyarrow_wrap_table(table)
        return py_arrow_table.column_names

    @property
    def schema(self):
        table = to_pyarrow_table(self.id.encode())
        py_arrow_table = pyarrow_wrap_table(table)
        return py_arrow_table.schema


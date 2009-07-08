# This file is part of NIT ( http://www.nitlanguage.org ).
#
# Copyright 2008 Jean Privat <jean@pryen.org>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Compile method bodies, statments and expressions to C.
package compiling_methods

import compiling_base
private import syntax

redef class CompilerVisitor
	# Compile a statment node
	fun compile_stmt(n: nullable PExpr)
	do
		if n == null then return
		#add_instr("/* Compile stmt {n.locate} */")
		n.prepare_compile_stmt(self)
		var i = cfc._variable_index
		n.compile_stmt(self)
		cfc._variable_index = i
	end

	# Compile is expression node
	fun compile_expr(n: PExpr): String
	do
		#add_instr("/* Compile expr {n.locate} */")
		var i = cfc._variable_index
		var s = n.compile_expr(self)
		cfc._variable_index = i
		if s[0] == ' ' or cfc.is_valid_variable(s) then
			return s
		end
		var v = cfc.get_var("Result")
		add_assignment(v, s)
		return v
	end

	# Ensure that a c expression is a var
	fun ensure_var(s: String, comment: String): String
	do
		if cfc.is_valid_variable(s) then
			add_instr("/* Ensure var {s}: {comment}*/")
			return s
		end
		var v = cfc.get_var(null)
		add_assignment(v, "{s} /* Ensure var: {comment}*/")
		return v
	end

	# Add a assignment between a variable and an expression
	fun add_assignment(v: String, s: String)
	do
		if v != s then
			add_instr("{v} = {s};")
		end
	end

	readable writable var _cfc: nullable CFunctionContext

	readable writable var _nmc: nullable NitMethodContext

	# C outputs written outside the current C function.
	readable writable var _out_contexts: Array[CContext] = new Array[CContext]

	# Generate an fprintf to display an error location
	fun printf_locate_error(node: PNode): String
	do
		var s = new Buffer.from("fprintf(stderr, \"")
		if nmc != null then s.append(" in %s")
		s.append(" (%s:%d)\\n\", ")
		if nmc != null then s.append("LOCATE_{nmc.method.cname}, ")
		s.append("LOCATE_{module.name}, {node.line_number});")
		return s.to_s
	end

	fun invoke_super_init_calls_after(start_prop: nullable MMMethod)
	do
		var n = nmc.method.node
		assert n isa AConcreteInitPropdef

		if n.super_init_calls.is_empty then return
		var i = 0
		var j = 0
		#var s = ""
		if start_prop != null then
			while n.super_init_calls[i] != start_prop do
				#s.append(" {n.super_init_calls[i]}")
				i += 1
			end
			i += 1
			#s.append(" {start_prop}")

			while n.explicit_super_init_calls[j] != start_prop do
				j += 1
			end
			j += 1
		end
		var stop_prop: nullable MMMethod = null
		if j < n.explicit_super_init_calls.length then
			stop_prop = n.explicit_super_init_calls[j]
		end
		var l = n.super_init_calls.length
		#s.append(" [")
		while i < l do
			var p = n.super_init_calls[i]
			if p == stop_prop then break
			var cargs = new Array[String]
			if p.signature.arity == 0 then
				cargs.add(cfc.varname(nmc.method_params[0]))
			else
				for va in nmc.method_params.as(not null) do
					cargs.add(cfc.varname(va))
				end
			end
			#s.append(" {p}")
			p.compile_stmt_call(self, cargs)
			i += 1
		end
		#s.append(" ]")
		#while i < l do
		#	s.append(" {n.super_init_calls[i]}")
		#	i += 1
		#end
		#if stop_prop != null then s.append(" (stop at {stop_prop})")
		#n.printl("implicit calls in {n.method}: {s}") 
	end
end

# A C function currently written
class CFunctionContext
	readable var _visitor: CompilerVisitor

	# Next available variable number
	var _variable_index: Int = 0

	# Total number of variable
	var _variable_index_max: Int = 0

	# Association between nit variable and the corrsponding c variable index
	var _varindexes: Map[Variable, Int] = new HashMap[Variable, Int]

	# Are we currenlty in a closure definition?
	readable writable var _closure: nullable NitMethodContext = null

	# Return the cvariable of a Nit variable
	fun varname(v: Variable): String
	do
		if v isa ClosureVariable then
			return closure_variable(_varindexes[v])
		else
			return variable(_varindexes[v])
		end
	end

	# Return the next available variable
	fun get_var(comment: nullable String): String
	do
		var v = variable(_variable_index)
		_variable_index = _variable_index + 1
		if _variable_index > _variable_index_max then
			_variable_index_max = _variable_index 
		end
		if comment != null then
			visitor.add_instr("/* Register {v}: {comment} */")
		end
		return v
	end

	fun register_variable(v: Variable): String
	do
		_varindexes[v] = _variable_index
		var s = get_var("Local variable")
		return s
	end

	# Next available closure variable number
	var _closurevariable_index: Int = 0

	fun register_closurevariable(v: ClosureVariable): String
	do
		var s = "closurevariable[{_closurevariable_index}]"
		_varindexes[v] = _closurevariable_index
		_closurevariable_index += 1
		if _closure != null then
			return "(closctx->{s})"
		else
			return s
		end
	end

	# Return the ith cvariable
	protected fun variable(i: Int): String
	do
		if closure != null then
			var vn = once new Array[String]
			if vn.length <= i then
				for j in [vn.length..i] do
					vn[j] = "(closctx->variable[{j}])"
				end
			end
			return vn[i]
		else
			var vn = once new Array[String]
			if vn.length <= i then
				for j in [vn.length..i] do
					vn[j] = "variable[{j}]"
				end
			end
			return vn[i]
		end
	end

	# Return the ith closurevariable
	protected fun closure_variable(i: Int): String
	do
		if closure != null then
			return "(closctx->closurevariable[{i}])"
		else
			return "closurevariable[{i}]"
		end
	end

	# Is s a valid variable
	protected fun is_valid_variable(s: String): Bool
	do
		for i in [0.._variable_index[ do
			if s == variable(i) then return true
		end
		return false
	end

	# Mark the variable available
	fun free_var(v: String)
	do
		# FIXME: So ugly..
		if v == variable(_variable_index-1) then
			_variable_index = _variable_index - 1
		end
	end

	# Generate the local variable declarations
	# To use at the end of the C function once all variables are known
	fun generate_var_decls
	do
		if _variable_index_max > 0 then
			visitor.add_decl("val_t variable[{_variable_index_max}];")
		else
			visitor.add_decl("val_t *variable = NULL;")
		end
		if _closurevariable_index > 0 then
			visitor.add_decl("struct WBT_ *closurevariable[{_closurevariable_index}];")
		else
			visitor.add_decl("struct WBT_ **closurevariable = NULL;")
		end
	end

	init(v: CompilerVisitor) do _visitor = v
end

# A Nit method currenlty compiled
class NitMethodContext
	# Current method compiled
	readable var _method: nullable MMMethod

	# Association between parameters and the corresponding variables
	readable writable var _method_params: nullable Array[ParamVariable]

	# Where a nit return must branch
	readable writable var _return_label: nullable String

	# Where a nit break must branch
	readable writable var _break_label: nullable String

	# Where a nit continue must branch
	readable writable var _continue_label: nullable String

	# Variable where a functionnal nit return must store its value
	readable writable var _return_value: nullable String

	# Variable where a functionnal nit break must store its value
	readable writable var _break_value: nullable String

	# Variable where a functionnal nit continue must store its value
	readable writable var _continue_value: nullable String

	init(method: nullable MMMethod)
	do
		_method = method
	end
end

###############################################################################

redef class ClosureVariable
	readable writable var _ctypename: nullable String
end

redef class MMAttribute
	# Compile a read acces on selffor a given reciever.
	fun compile_isset(v: CompilerVisitor, n: PNode, recv: String): String
	do
		return "TAG_Bool({global.attr_access}({recv})!=NIT_NULL) /* isset {local_class}::{name}*/"
	end

	# Compile a read acces on selffor a given reciever.
	fun compile_read_access(v: CompilerVisitor, n: PNode, recv: String): String
	do
		var res = "{global.attr_access}({recv}) /*{local_class}::{name}*/"
		if not signature.return_type.is_nullable then
			res = v.ensure_var(res, "{local_class}::{name}")
			v.add_instr("if ({res} == NIT_NULL) \{ fprintf(stderr, \"Uninitialized attribute %s\", \"{name}\"); {v.printf_locate_error(n)} nit_exit(1); } /* implicit isset */;")
		end
		return res
	end

	# Compile a write acces on selffor a given reciever.
	fun compile_write_access(v: CompilerVisitor, n: nullable PNode, recv: String, value: String)
	do
		v.add_instr("{global.attr_access}({recv}) /*{local_class}::{name}*/ = {value};")
	end
end

redef class MMLocalProperty
	# Compile the property as a C property
	fun compile_property_to_c(v: CompilerVisitor) do end
end

redef class MMMethod
	# Compile as an expression.
	# require that signature.return_type != null
	fun compile_expr_call(v: CompilerVisitor, cargs: Array[String]): String
	do
		assert signature.return_type != null
		var s = intern_compile_call(v, cargs)
		assert s != null
		return s
	end

	# Compile as a statement.
	# require that signature.return_type == null
	fun compile_stmt_call(v: CompilerVisitor, cargs: Array[String])
	do
		assert signature.return_type == null
		var s = intern_compile_call(v, cargs)
		assert s == null
	end

	# Compile a call on self for given arguments
	# Most calls are compiled with a table access,
	# primitive calles are inlined
	# == and != are guarded and possibly inlined
	private fun intern_compile_call(v: CompilerVisitor, cargs: Array[String]): nullable String
	do
		var i = self
		if i isa MMSrcMethod then
			if i isa MMMethSrcMethod and i.node isa AInternMethPropdef or 
				(i.local_class.name == (once "Array".to_symbol) and name == (once "[]".to_symbol))
			then
				var e = i.do_compile_inside(v, cargs)
				return e
			end
		end
		var ee = once "==".to_symbol
		var ne = once "!=".to_symbol
		if name == ne then
			var eqp = signature.recv.local_class.select_method(ee)
			var eqcall = eqp.compile_expr_call(v, cargs)
			return "TAG_Bool(!UNTAG_Bool({eqcall}))"
		end
		if global.is_init then
			cargs = cargs.to_a
			cargs.add("init_table /*YYY*/")
		end

		var m = "{global.meth_call}({cargs[0]})"
		var vcall = "{m}({cargs.join(", ")}) /*{local_class}::{name}*/"
		if name == ee then
			vcall = "UNTAG_Bool({vcall})"
			var obj = once "Object".to_symbol
			if i.local_class.name == obj then
				vcall = "(({m}=={i.cname})?(IS_EQUAL_NN({cargs[0]},{cargs[1]})):({vcall}))"
			end
			vcall = "TAG_Bool(({cargs.first} == {cargs[1]}) || (({cargs.first} != NIT_NULL) && {vcall}))"
		end
		if signature.return_type != null then
			return vcall
		else
			v.add_instr(vcall + ";")
			return null
		end
	end

	# Compile a call on self for given arguments and given closures
	fun compile_call_and_closures(v: CompilerVisitor, cargs: Array[String], clos_defs: nullable Array[PClosureDef]): nullable String
	do
		var ve: String
		var arity = 0
		if clos_defs != null then arity = clos_defs.length

		# Prepare result value.
		# In case of procedure, the return value is still used to intercept breaks
		var old_bv = v.nmc.break_value
		ve = v.cfc.get_var("Closure return value and escape marker")
		v.nmc.break_value = ve

		# Compile closure to c function
		var realcargs = new Array[String] # Args to pass to the C function call
		var closcns = new Array[String] # Closure C structure names
		realcargs.add_all(cargs)
		for i in [0..arity[ do
			var cn = clos_defs[i].compile_closure(v, closure_cname(i))
			closcns.add(cn)
			realcargs.add(cn)
		end
		for i in [arity..signature.closures.length[ do
			realcargs.add("NULL")
		end

		v.nmc.break_value = old_bv

		# Call
		var e = intern_compile_call(v, realcargs)
		if e != null then
			v.add_assignment(ve, e)
			e = ve
		end

		# Intercept returns and breaks
		for i in [0..arity[ do
			# A break or a return is intercepted
			v.add_instr("if ({closcns[i]}->has_broke != NULL) \{")
			v.indent
			# A passtrought break or a return is intercepted: go the the next closure
			v.add_instr("if ({closcns[i]}->has_broke != &({ve})) \{")
			v.indent
			if v.cfc.closure == v.nmc then v.add_instr("closctx->has_broke = {closcns[i]}->has_broke; closctx->broke_value = {closcns[i]}->broke_value;")
			v.add_instr("goto {v.nmc.return_label};")
			v.unindent
			# A direct break is interpected
			if e != null then
				# overwrite the returned value in a function
				v.add_instr("\} else {ve} = {closcns[i]}->broke_value;")
			else
				# Do nothing in a procedure
				v.add_instr("\}")
			end
			v.unindent
			v.add_instr("\}")
		end
		return e
	end

	# Compile a call as constructor with given args
	fun compile_constructor_call(v: CompilerVisitor, recvtype: MMType, cargs: Array[String]): String
	do
		return "NEW_{recvtype.local_class}_{global.intro.cname}({cargs.join(", ")}) /*new {recvtype}*/"
	end

	# Compile a call as call-next-method on self with given args
	fun compile_super_call(v: CompilerVisitor, cargs: Array[String]): String
	do
		if global.is_init then cargs.add("init_table")
		var m = "{super_meth_call}({cargs[0]})"
		var vcall = "{m}({cargs.join(", ")}) /*super {local_class}::{name}*/"
		return vcall
	end

	# Cname of the i-th closure C struct type
	protected fun closure_cname(i: Int): String
	do
		return "FWBT_{cname}_{i}"
	end

	# Compile and declare the signature to C
	protected fun decl_csignature(v: CompilerVisitor, args: Array[String]): String
	do
		var params = new Array[String]
		params.add("val_t {args[0]}")
		for i in [0..signature.arity[ do
			var p = "val_t {args[i+1]}"
			params.add(p)
		end

		var first_closure_index = signature.arity + 1 # Wich parameter is the first closure
		for i in [0..signature.closures.length[ do
			var closcn = closure_cname(i)
			var cs = signature.closures[i].signature # Closure signature
			var subparams = new Array[String] # Parameters of the closure
			subparams.add("struct WBT_ *")
			for j in [0..cs.arity[ do
				var p = "val_t"
				subparams.add(p)
			end
			var r = "void"
			if cs.return_type != null then r = "val_t"
			params.add("struct WBT_ *{args[first_closure_index+i]}")
			v.add_decl("typedef {r} (*{closcn})({subparams.join(", ")});")
		end

		if global.is_init then
			params.add("int* init_table")
		end

		var ret: String
		if signature.return_type != null then
			ret = "val_t"
		else
			ret = "void"
		end

		var p = params.join(", ")
		var s = "{ret} {cname}({p})"
		v.add_decl("typedef {ret} (* {cname}_t)({p});")
		v.add_decl(s + ";")
		return s
	end

	redef fun compile_property_to_c(v)
	do
		v.cfc = new CFunctionContext(v)

		var args = new Array[String]
		args.add(" self")
		for i in [0..signature.arity[ do
			args.add(" param{i}")
		end
		for i in [0..signature.closures.length[ do
			args.add(" wd{i}")
		end
		var cs = decl_csignature(v, args)
		v.add_decl("#define LOCATE_{cname} \"{full_name}\"")

		v.add_instr("{cs} \{")
		v.indent
		var ctx_old = v.ctx
		v.ctx = new CContext

		v.out_contexts.clear

		var itpos: nullable String = null
		if global.is_init then
			itpos = "itpos{v.new_number}"
			v.add_decl("int {itpos} = VAL2OBJ(self)->vft[{local_class.global.init_table_pos_id}].i;")
			v.add_instr("if (init_table[{itpos}]) return;")
		end

		var ln = 0
		var s = self
		if s.node != null then ln = s.node.line_number
		v.add_decl("struct trace_t trace = \{NULL, NULL, {ln}, LOCATE_{cname}};")
		v.add_instr("trace.prev = tracehead; tracehead = &trace;")
		v.add_instr("trace.file = LOCATE_{module.name};")

		var s = do_compile_inside(v, args)

		if itpos != null then
			v.add_instr("init_table[{itpos}] = 1;")
		end

		v.add_instr("tracehead = trace.prev;")
		if s == null then
			v.add_instr("return;")
		else
			v.add_instr("return {s};")
		end

		v.cfc.generate_var_decls

		ctx_old.append(v.ctx)
		v.ctx = ctx_old
		v.unindent
		v.add_instr("}")

		for ctx in v.out_contexts do v.ctx.merge(ctx)
	end

	# Compile the method body inline
	fun do_compile_inside(v: CompilerVisitor, params: Array[String]): nullable String is abstract
end

redef class MMReadImplementationMethod
	redef fun do_compile_inside(v, params)
	do
		return node.prop.compile_read_access(v, node, params[0])
	end
end

redef class MMWriteImplementationMethod
	redef fun do_compile_inside(v, params)
	do
		node.prop.compile_write_access(v, node, params[0], params[1])
		return null
	end
end

redef class MMMethSrcMethod
	redef fun do_compile_inside(v, params)
	do
		return node.do_compile_inside(v, self, params)
	end
end

redef class MMImplicitInit
	redef fun do_compile_inside(v, params)
	do
		var f = params.length - unassigned_attributes.length
		var recv = params.first
		for sp in super_inits do
			assert sp isa MMMethod
			var args_recv = [recv]
			if sp == super_init then
				var args = new Array[String].with_capacity(f)
				args.add(recv)
				for i in [1..f[ do
					args.add(params[i])
				end
				sp.compile_stmt_call(v, args)
			else
				sp.compile_stmt_call(v, args_recv)
			end
		end
		for i in [f..params.length[ do
			var attribute = unassigned_attributes[i-f]
			attribute.compile_write_access(v, null, recv, params[i])
		end
		return null
	end
end

redef class MMType
	# Compile a subtype check to self
	# Return a NIT Bool
	fun compile_cast(v: CompilerVisitor, recv: String, fromtype: MMType): String
	do
		# Fixme: handle formaltypes
		var g = local_class.global
		var s = ""
		if fromtype.is_nullable then
			if self.is_nullable then
				s = "({recv}==NIT_NULL) || "
			else
				s = "({recv}!=NIT_NULL) && "
			end
		else
			# FIXME This is used to not break code without the nullable KW
			s = "({recv}==NIT_NULL) || "
		end
		return "TAG_Bool({s}VAL_ISA({recv}, {g.color_id}, {g.id_id})) /*cast {self}*/"
	end

	# Compile a cast assertion
	fun compile_type_check(v: CompilerVisitor, recv: String, n: PNode, fromtype: MMType)
	do
		# Fixme: handle formaltypes
		var g = local_class.global
		var s = ""
		if fromtype.is_nullable then
			if self.is_nullable then
				s = "({recv}!=NIT_NULL) && "
			else
				s = "({recv}==NIT_NULL) || "
			end
		else
			# FIXME This is used to not break code without the nullable KW
			s = "({recv}!=NIT_NULL) && "
		end
		v.add_instr("if ({s}!VAL_ISA({recv}, {g.color_id}, {g.id_id})) \{ fprintf(stderr, \"Cast failed\"); {v.printf_locate_error(n)} nit_exit(1); } /*cast {self}*/;")
	end

	# Compile a notnull cast assertion
	fun compile_notnull_check(v: CompilerVisitor, recv: String, n: PNode)
	do
		if is_nullable then
			v.add_instr("if (({recv}==NIT_NULL)) \{ fprintf(stderr, \"Cast failed\"); {v.printf_locate_error(n)} nit_exit(1); } /*cast {self}*/;")
		end
	end
end

###############################################################################

redef class AMethPropdef
	# Compile the method body
	fun do_compile_inside(v: CompilerVisitor, method: MMMethod, params: Array[String]): nullable String is abstract
end

redef class PSignature
	fun compile_parameters(v: CompilerVisitor, orig_sig: MMSignature, params: Array[String]) is abstract
end

redef class ASignature
	redef fun compile_parameters(v: CompilerVisitor, orig_sig: MMSignature, params: Array[String])
	do
		for ap in n_params do
			var cname = v.cfc.register_variable(ap.variable)
			v.nmc.method_params.add(ap.variable)
			var orig_type = orig_sig[ap.position]
			if not orig_type < ap.variable.stype.as(not null) then
				# FIXME: do not test always
				# FIXME: handle formal types
				v.add_instr("/* check if p<{ap.variable.stype} with p:{orig_type} */")
				ap.variable.stype.compile_type_check(v, params[ap.position], ap, orig_type)
			end
			v.add_assignment(cname, params[ap.position])
		end
		for i in [0..n_closure_decls.length[ do
			var wd = n_closure_decls[i]
			var cname = v.cfc.register_closurevariable(wd.variable)
			wd.variable.ctypename = v.nmc.method.closure_cname(i)
			v.add_assignment(cname, "{params[orig_sig.arity + i]}")
		end
	end
end

redef class AConcreteMethPropdef
	redef fun do_compile_inside(v, method, params)
	do
		var old_nmc = v.nmc
		v.nmc = new NitMethodContext(method)

		var selfcname = v.cfc.register_variable(self_var)
		v.add_assignment(selfcname, params[0])
		params.shift
		v.nmc.method_params = [self_var]

		var orig_meth: MMLocalProperty = method.global.intro
		var orig_sig = orig_meth.signature_for(method.signature.recv)
		if n_signature != null then
			n_signature.compile_parameters(v, orig_sig, params)
		end

		v.nmc.return_label = "return_label{v.new_number}"
		v.nmc.return_value = v.cfc.get_var("Method return value and escape marker")
		if self isa AConcreteInitPropdef then
			v.invoke_super_init_calls_after(null)
		end
		v.compile_stmt(n_block)
		v.add_instr("{v.nmc.return_label}: while(false);")

		var ret: nullable String = null
		if method.signature.return_type != null then
			ret = v.nmc.return_value
		end

		v.nmc = old_nmc
		return ret
	end
end

redef class ADeferredMethPropdef
	redef fun do_compile_inside(v, method, params)
	do
		v.add_instr("fprintf(stderr, \"Deferred method called\");")
		v.add_instr(v.printf_locate_error(self))
		v.add_instr("nit_exit(1);")
		if method.signature.return_type != null then
			return("NIT_NULL")
		else
			return null
		end
	end
end

redef class AExternMethPropdef
	redef fun do_compile_inside(v, method, params)
	do
		var ename = "{method.module.name}_{method.local_class.name}_{method.local_class.name}_{method.name}_{method.signature.arity}"
		if n_extern != null then
			ename = n_extern.text
			ename = ename.substring(1, ename.length-2)
		end
		var sig = method.signature
		if params.length != sig.arity + 1 then
			printl("par:{params.length} sig:{sig.arity}")
		end
		var args = new Array[String]
		args.add(sig.recv.unboxtype(params[0]))
		for i in [0..sig.arity[ do
			args.add(sig[i].unboxtype(params[i+1]))
		end
		var s = "{ename}({args.join(", ")})"
		if sig.return_type != null then
			return sig.return_type.boxtype(s)
		else
			v.add_instr("{s};")
			return null
		end
	end
end

redef class AInternMethPropdef
	redef fun do_compile_inside(v, method, p)
	do
		var c = method.local_class.name
		var n = method.name
		var s: nullable String = null
		if c == once "Int".to_symbol then
			if n == once "object_id".to_symbol then
				s = "{p[0]}"
			else if n == once "unary -".to_symbol then
				s = "TAG_Int(-UNTAG_Int({p[0]}))"
			else if n == once "output".to_symbol then
				v.add_instr("printf(\"%ld\\n\", UNTAG_Int({p[0]}));")
			else if n == once "ascii".to_symbol then
				s = "TAG_Char(UNTAG_Int({p[0]}))"
			else if n == once "succ".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})+1)"
			else if n == once "prec".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})-1)"
			else if n == once "to_f".to_symbol then
				s = "BOX_Float((float)UNTAG_Int({p[0]}))"
			else if n == once "+".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})+UNTAG_Int({p[1]}))" 
			else if n == once "-".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})-UNTAG_Int({p[1]}))" 
			else if n == once "*".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})*UNTAG_Int({p[1]}))" 
			else if n == once "/".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})/UNTAG_Int({p[1]}))" 
			else if n == once "%".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})%UNTAG_Int({p[1]}))" 
			else if n == once "<".to_symbol then
				s = "TAG_Bool(UNTAG_Int({p[0]})<UNTAG_Int({p[1]}))" 
			else if n == once ">".to_symbol then
				s = "TAG_Bool(UNTAG_Int({p[0]})>UNTAG_Int({p[1]}))" 
			else if n == once "<=".to_symbol then
				s = "TAG_Bool(UNTAG_Int({p[0]})<=UNTAG_Int({p[1]}))" 
			else if n == once ">=".to_symbol then
				s = "TAG_Bool(UNTAG_Int({p[0]})>=UNTAG_Int({p[1]}))" 
			else if n == once "lshift".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})<<UNTAG_Int({p[1]}))" 
			else if n == once "rshift".to_symbol then
				s = "TAG_Int(UNTAG_Int({p[0]})>>UNTAG_Int({p[1]}))"
			else if n == once "==".to_symbol then
				s = "TAG_Bool(({p[0]})==({p[1]}))" 
			else if n == once "!=".to_symbol then
				s = "TAG_Bool(({p[0]})!=({p[1]}))" 
			end
		else if c == once "Float".to_symbol then
			if n == once "object_id".to_symbol then
				s = "TAG_Int((bigint)UNBOX_Float({p[0]}))"
			else if n == once "unary -".to_symbol then
				s = "BOX_Float(-UNBOX_Float({p[0]}))"
			else if n == once "output".to_symbol then
				v.add_instr("printf(\"%f\\n\", UNBOX_Float({p[0]}));")
			else if n == once "to_i".to_symbol then
				s = "TAG_Int((bigint)UNBOX_Float({p[0]}))"
			else if n == once "+".to_symbol then
				s = "BOX_Float(UNBOX_Float({p[0]})+UNBOX_Float({p[1]}))" 
			else if n == once "-".to_symbol then
				s = "BOX_Float(UNBOX_Float({p[0]})-UNBOX_Float({p[1]}))" 
			else if n == once "*".to_symbol then
				s = "BOX_Float(UNBOX_Float({p[0]})*UNBOX_Float({p[1]}))" 
			else if n == once "/".to_symbol then
				s = "BOX_Float(UNBOX_Float({p[0]})/UNBOX_Float({p[1]}))" 
			else if n == once "<".to_symbol then
				s = "TAG_Bool(UNBOX_Float({p[0]})<UNBOX_Float({p[1]}))" 
			else if n == once ">".to_symbol then
				s = "TAG_Bool(UNBOX_Float({p[0]})>UNBOX_Float({p[1]}))" 
			else if n == once "<=".to_symbol then
				s = "TAG_Bool(UNBOX_Float({p[0]})<=UNBOX_Float({p[1]}))" 
			else if n == once ">=".to_symbol then
				s = "TAG_Bool(UNBOX_Float({p[0]})>=UNBOX_Float({p[1]}))" 
			end
		else if c == once "Char".to_symbol then
			if n == once "object_id".to_symbol then
				s = "TAG_Int(UNTAG_Char({p[0]}))"
			else if n == once "unary -".to_symbol then
				s = "TAG_Char(-UNTAG_Char({p[0]}))"
			else if n == once "output".to_symbol then
				v.add_instr("printf(\"%c\", (unsigned char)UNTAG_Char({p[0]}));")
			else if n == once "ascii".to_symbol then
				s = "TAG_Int((unsigned char)UNTAG_Char({p[0]}))"
			else if n == once "succ".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})+1)"
			else if n == once "prec".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})-1)"
			else if n == once "to_i".to_symbol then
				s = "TAG_Int(UNTAG_Char({p[0]})-'0')"
			else if n == once "+".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})+UNTAG_Char({p[1]}))" 
			else if n == once "-".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})-UNTAG_Char({p[1]}))" 
			else if n == once "*".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})*UNTAG_Char({p[1]}))" 
			else if n == once "/".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})/UNTAG_Char({p[1]}))" 
			else if n == once "%".to_symbol then
				s = "TAG_Char(UNTAG_Char({p[0]})%UNTAG_Char({p[1]}))" 
			else if n == once "<".to_symbol then
				s = "TAG_Bool(UNTAG_Char({p[0]})<UNTAG_Char({p[1]}))" 
			else if n == once ">".to_symbol then
				s = "TAG_Bool(UNTAG_Char({p[0]})>UNTAG_Char({p[1]}))" 
			else if n == once "<=".to_symbol then
				s = "TAG_Bool(UNTAG_Char({p[0]})<=UNTAG_Char({p[1]}))" 
			else if n == once ">=".to_symbol then
				s = "TAG_Bool(UNTAG_Char({p[0]})>=UNTAG_Char({p[1]}))" 
			else if n == once "==".to_symbol then
				s = "TAG_Bool(({p[0]})==({p[1]}))" 
			else if n == once "!=".to_symbol then
				s = "TAG_Bool(({p[0]})!=({p[1]}))" 
			end
		else if c == once "Bool".to_symbol then
			if n == once "object_id".to_symbol then
				s = "TAG_Int(UNTAG_Bool({p[0]}))"
			else if n == once "unary -".to_symbol then
				s = "TAG_Bool(-UNTAG_Bool({p[0]}))"
			else if n == once "output".to_symbol then
				v.add_instr("(void)printf(UNTAG_Bool({p[0]})?\"true\\n\":\"false\\n\");")
			else if n == once "ascii".to_symbol then
				s = "TAG_Bool(UNTAG_Bool({p[0]}))"
			else if n == once "to_i".to_symbol then
				s = "TAG_Int(UNTAG_Bool({p[0]}))"
			else if n == once "==".to_symbol then
				s = "TAG_Bool(({p[0]})==({p[1]}))" 
			else if n == once "!=".to_symbol then
				s = "TAG_Bool(({p[0]})!=({p[1]}))" 
			end
		else if c == once "NativeArray".to_symbol then
			if n == once "object_id".to_symbol then
				s = "TAG_Int(UNBOX_NativeArray({p[0]}))"
			else if n == once "[]".to_symbol then
				s = "UNBOX_NativeArray({p[0]})[UNTAG_Int({p[1]})]"
			else if n == once "[]=".to_symbol then
				v.add_instr("UNBOX_NativeArray({p[0]})[UNTAG_Int({p[1]})]={p[2]};")
			else if n == once "copy_to".to_symbol then
				v.add_instr("(void)memcpy(UNBOX_NativeArray({p[1]}), UNBOX_NativeArray({p[0]}), UNTAG_Int({p[2]})*sizeof(val_t));")
			end	
		else if c == once "NativeString".to_symbol then
			if n == once "object_id".to_symbol then
				s = "TAG_Int(UNBOX_NativeString({p[0]}))"
			else if n == once "atoi".to_symbol then
				s = "TAG_Int(atoi(UNBOX_NativeString({p[0]})))"
			else if n == once "[]".to_symbol then
				s = "TAG_Char(UNBOX_NativeString({p[0]})[UNTAG_Int({p[1]})])"
			else if n == once "[]=".to_symbol then
				v.add_instr("UNBOX_NativeString({p[0]})[UNTAG_Int({p[1]})]=UNTAG_Char({p[2]});")
			else if n == once "copy_to".to_symbol then
				v.add_instr("(void)memcpy(UNBOX_NativeString({p[1]})+UNTAG_Int({p[4]}), UNBOX_NativeString({p[0]})+UNTAG_Int({p[3]}), UNTAG_Int({p[2]}));")
			end
		else if n == once "object_id".to_symbol then
			s = "TAG_Int((bigint){p[0]})"
		else if n == once "sys".to_symbol then
			s = "(G_sys)"
		else if n == once "is_same_type".to_symbol then
			s = "TAG_Bool((VAL2VFT({p[0]})==VAL2VFT({p[1]})))"
		else if n == once "exit".to_symbol then
			v.add_instr("exit(UNTAG_Int({p[1]}));")
		else if n == once "calloc_array".to_symbol then
			s = "BOX_NativeArray((val_t*)malloc((UNTAG_Int({p[1]}) * sizeof(val_t))))"
		else if n == once "calloc_string".to_symbol then
			s = "BOX_NativeString((char*)malloc((UNTAG_Int({p[1]}) * sizeof(char))))"

		else
			stderr.write("{locate}: Fatal error: unknown intern method {method.full_name}.\n")
			exit(1)
		end
		if method.signature.return_type != null and s == null then
			s = "NIT_NULL /*stub*/"
		end
		return s
	end
end

###############################################################################

redef class PExpr
	# Compile the node as an expression
	# Only the visitor should call it
	fun compile_expr(v: CompilerVisitor): String is abstract

	# Prepare a call of node as a statement
	# Only the visitor should call it
	# It's used for local variable managment
	fun prepare_compile_stmt(v: CompilerVisitor) do end

	# Compile the node as a statement
	# Only the visitor should call it
	fun compile_stmt(v: CompilerVisitor) do printl("Error!")
end

redef class ABlockExpr
	redef fun compile_stmt(v)
	do
		for n in n_expr do
			v.compile_stmt(n)
		end
	end
end

redef class AVardeclExpr
	redef fun prepare_compile_stmt(v)
	do
		v.cfc.register_variable(variable)
	end

	redef fun compile_stmt(v)
	do
		var cname = v.cfc.varname(variable)
		if n_expr == null then
			v.add_instr("/*{cname} is variable {variable.name}*/")
		else
			var e = v.compile_expr(n_expr.as(not null))
			v.add_assignment(cname, e)
		end
	end
end

redef class AReturnExpr
	redef fun compile_stmt(v)
	do
		if n_expr != null then
			var e = v.compile_expr(n_expr.as(not null))
			v.add_assignment(v.nmc.return_value.as(not null), e)
		end
		if v.cfc.closure == v.nmc then v.add_instr("closctx->has_broke = &({v.nmc.return_value});")
		v.add_instr("goto {v.nmc.return_label};")
	end
end

redef class ABreakExpr
	redef fun compile_stmt(v)
	do
		if n_expr != null then
			var e = v.compile_expr(n_expr.as(not null))
			v.add_assignment(v.nmc.break_value.as(not null), e)
		end
		if v.cfc.closure == v.nmc then v.add_instr("closctx->has_broke = &({v.nmc.break_value}); closctx->broke_value = *closctx->has_broke;")
		v.add_instr("goto {v.nmc.break_label};")
	end
end

redef class AContinueExpr
	redef fun compile_stmt(v)
	do
		if n_expr != null then
			var e = v.compile_expr(n_expr.as(not null))
			v.add_assignment(v.nmc.continue_value.as(not null), e)
		end
		v.add_instr("goto {v.nmc.continue_label};")
	end
end

redef class AAbortExpr
	redef fun compile_stmt(v)
	do
		v.add_instr("fprintf(stderr, \"Aborted\"); {v.printf_locate_error(self)} nit_exit(1);")
	end
end

redef class ADoExpr
	redef fun compile_stmt(v)
	do
		v.compile_stmt(n_block)
	end
end

redef class AIfExpr
	redef fun compile_stmt(v)
	do
		var e = v.compile_expr(n_expr)
		v.add_instr("if (UNTAG_Bool({e})) \{ /*if*/")
		v.cfc.free_var(e)
		if n_then != null then
			v.indent
			v.compile_stmt(n_then)
			v.unindent
		end
		if n_else != null then
			v.add_instr("} else \{ /*if*/")
			v.indent
			v.compile_stmt(n_else)
			v.unindent
		end
		v.add_instr("}")
	end
end

redef class AIfexprExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		v.add_instr("if (UNTAG_Bool({e})) \{ /*if*/")
		v.cfc.free_var(e)
		v.indent
		var e = v.ensure_var(v.compile_expr(n_then), "Then value")
		v.unindent
		v.add_instr("} else \{ /*if*/")
		v.cfc.free_var(e)
		v.indent
		var e2 = v.ensure_var(v.compile_expr(n_else), "Else value")
		v.add_assignment(e, e2)
		v.unindent
		v.add_instr("}")
		return e
	end
end

class AControlableBlock
special PExpr
	fun compile_inside_block(v: CompilerVisitor) is abstract
	redef fun compile_stmt(v)
	do
		var old_break_label = v.nmc.break_label
		var old_continue_label = v.nmc.continue_label
		var id = v.new_number
		v.nmc.break_label = "break_{id}"
		v.nmc.continue_label = "continue_{id}"

		compile_inside_block(v)


		v.nmc.break_label = old_break_label
		v.nmc.continue_label = old_continue_label
	end
end

redef class AWhileExpr
special AControlableBlock
	redef fun compile_inside_block(v)
	do
		v.add_instr("while (true) \{ /*while*/")
		v.indent
		var e = v.compile_expr(n_expr)
		v.add_instr("if (!UNTAG_Bool({e})) break; /* while*/")
		v.cfc.free_var(e)
		v.compile_stmt(n_block)
		v.add_instr("{v.nmc.continue_label}: while(0);")
		v.unindent
		v.add_instr("}")
		v.add_instr("{v.nmc.break_label}: while(0);")
	end
end

redef class AForExpr
special AControlableBlock
	redef fun compile_inside_block(v)
	do
		var e = v.compile_expr(n_expr)
		var ittype = meth_iterator.signature.return_type
		v.cfc.free_var(e)
		var iter = v.cfc.get_var("For iterator")
		v.add_assignment(iter, meth_iterator.compile_expr_call(v, [e]))
		v.add_instr("while (true) \{ /*for*/")
		v.indent
		var ok = v.cfc.get_var("For 'is_ok' result")
		v.add_assignment(ok, meth_is_ok.compile_expr_call(v, [iter]))
		v.add_instr("if (!UNTAG_Bool({ok})) break; /*for*/")
		v.cfc.free_var(ok)
		var e = meth_item.compile_expr_call(v, [iter])
		e = v.ensure_var(e, "For item")
		var cname = v.cfc.register_variable(variable)
		v.add_assignment(cname, e)
		v.compile_stmt(n_block)
		v.add_instr("{v.nmc.continue_label}: while(0);")
		meth_next.compile_stmt_call(v, [iter])
		v.unindent
		v.add_instr("}")
		v.add_instr("{v.nmc.break_label}: while(0);")
	end
end

redef class AAssertExpr
	redef fun compile_stmt(v)
	do
		var e = v.compile_expr(n_expr)
		var s = ""
		if n_id != null then
			s = " '{n_id.text}' "
		end
		v.add_instr("if (!UNTAG_Bool({e})) \{ fprintf(stderr, \"Assert%s failed\", \"{s}\"); {v.printf_locate_error(self)} nit_exit(1);}")
	end
end

redef class AVarExpr
	redef fun compile_expr(v)
	do
		return " {v.cfc.varname(variable)} /*{variable.name}*/"
	end
end

redef class AVarAssignExpr
	redef fun compile_stmt(v)
	do
		var e = v.compile_expr(n_value)
		v.add_assignment(v.cfc.varname(variable), "{e} /*{variable.name}=*/")
	end
end

redef class AVarReassignExpr
	redef fun compile_stmt(v)
	do
		var e1 = v.cfc.varname(variable)
		var e2 = v.compile_expr(n_value)
		var e3 = assign_method.compile_expr_call(v, [e1, e2])
		v.add_assignment(v.cfc.varname(variable), "{e3} /*{variable.name}*/")
	end
end

redef class ASelfExpr
	redef fun compile_expr(v)
	do
		return v.cfc.varname(v.nmc.method_params[0])
	end
end

redef class AOrExpr
	redef fun compile_expr(v)
	do
		var e = v.ensure_var(v.compile_expr(n_expr), "Left 'or' operand")
		v.add_instr("if (!UNTAG_Bool({e})) \{ /* or */")
		v.cfc.free_var(e)
		v.indent
		var e2 = v.compile_expr(n_expr2)
		v.add_assignment(e, e2)
		v.unindent
		v.add_instr("}")
		return e
	end
end

redef class AAndExpr
	redef fun compile_expr(v)
	do
		var e = v.ensure_var(v.compile_expr(n_expr), "Left 'and' operand")
		v.add_instr("if (UNTAG_Bool({e})) \{ /* and */")
		v.cfc.free_var(e)
		v.indent
		var e2 = v.compile_expr(n_expr2)
		v.add_assignment(e, e2)
		v.unindent
		v.add_instr("}")
		return e
	end
end

redef class ANotExpr
	redef fun compile_expr(v)
	do
		return " TAG_Bool(!UNTAG_Bool({v.compile_expr(n_expr)}))"
	end
end

redef class AEeExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		var e2 = v.compile_expr(n_expr2)
		return "TAG_Bool(IS_EQUAL_NN({e},{e2}))"
	end
end

redef class AIsaExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		return n_type.stype.compile_cast(v, e, n_expr.stype)
	end
end

redef class AAsCastExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		n_type.stype.compile_type_check(v, e, self, n_expr.stype)
		return e
	end
end

redef class AAsNotnullExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		n_expr.stype.compile_notnull_check(v, e, self)
		return e
	end
end

redef class ATrueExpr
	redef fun compile_expr(v)
	do
		return " TAG_Bool(true)"
	end
end

redef class AFalseExpr
	redef fun compile_expr(v)
	do
		return " TAG_Bool(false)"
	end
end

redef class AIntExpr
	redef fun compile_expr(v)
	do
		return " TAG_Int({n_number.text})"
	end
end

redef class AFloatExpr
	redef fun compile_expr(v)
	do
		return "BOX_Float({n_float.text})"
	end
end

redef class ACharExpr
	redef fun compile_expr(v)
	do
		return " TAG_Char({n_char.text})"
	end
end

redef class AStringFormExpr
	redef fun compile_expr(v)
	do
		compute_string_info
		var i = v.new_number
		var cvar = v.cfc.get_var("Once String constant")
		v.add_decl("static val_t once_value_{i} = NIT_NULL; /* Once value for string {cvar}*/")
		v.add_instr("if (once_value_{i} != NIT_NULL) {cvar} = once_value_{i};")
		v.add_instr("else \{")
		v.indent
		v.cfc.free_var(cvar)
		var e = meth_with_native.compile_constructor_call(v, stype, ["BOX_NativeString(\"{_cstring}\")", "TAG_Int({_cstring_length})"])
		v.add_assignment(cvar, e)
		v.add_instr("once_value_{i} = {cvar};")
		v.unindent
		v.add_instr("}")
		return cvar
	end

	# The raw string value
	protected fun string_text: String is abstract

	# The string in a C native format
	protected var _cstring: nullable String

	# The string length in bytes
	protected var _cstring_length: nullable Int

	# Compute _cstring and _cstring_length using string_text
	protected fun compute_string_info
	do
		var len = 0
		var str = string_text
		var res = new Buffer
		var i = 0
		while i < str.length do
			var c = str[i]
			if c == '\\' then
				i = i + 1
				var c2 = str[i]
				if c2 != '{' and c2 != '}' then
					res.add(c)
				end
				c = c2
			end
			len = len + 1
			res.add(c)
			i = i + 1
		end
		_cstring = res.to_s
		_cstring_length = len
	end
end

redef class AStringExpr
	redef fun string_text do return n_string.text.substring(1, n_string.text.length - 2)
end
redef class AStartStringExpr
	redef fun string_text do return n_string.text.substring(1, n_string.text.length - 2)
end
redef class AMidStringExpr
	redef fun string_text do return n_string.text.substring(1, n_string.text.length - 2)
end
redef class AEndStringExpr
	redef fun string_text do return n_string.text.substring(1, n_string.text.length - 2)
end

redef class ASuperstringExpr
	redef fun compile_expr(v)
	do
		var array = meth_with_capacity.compile_constructor_call(v, atype, ["TAG_Int({n_exprs.length})"])
		array = v.ensure_var(array, "Array (for super-string)")

		for ne in n_exprs do
			var e = v.ensure_var(v.compile_expr(ne), "super-string element")
			if ne.stype != stype then
				v.cfc.free_var(e)
				e = meth_to_s.compile_expr_call(v, [e])
			end
			v.cfc.free_var(e)
			meth_add.compile_stmt_call(v, [array, e])
		end

		return meth_to_s.compile_expr_call(v, [array])
	end
end

redef class ANullExpr
	redef fun compile_expr(v)
	do
		return " NIT_NULL /*null*/"
	end
end

redef class AArrayExpr
	redef fun compile_expr(v)
	do
		var recv = meth_with_capacity.compile_constructor_call(v, stype, ["TAG_Int({n_exprs.length})"])
		recv = v.ensure_var(recv, "Literal array")

		for ne in n_exprs do
			var e = v.compile_expr(ne)
			meth_add.compile_stmt_call(v, [recv, e])
		end
		return recv
	end
end

redef class ARangeExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		var e2 = v.compile_expr(n_expr2)
		return meth_init.compile_constructor_call(v, stype, [e, e2])
	end
end

redef class ASuperExpr
	redef fun compile_stmt(v)
	do
		var e = intern_compile_call(v)
		if e != null then
			v.add_instr(e + ";")
		end
	end

	redef fun compile_expr(v)
	do
		var e = intern_compile_call(v)
		assert e != null
		return e
	end

	private fun intern_compile_call(v: CompilerVisitor): nullable String
	do
		var arity = v.nmc.method_params.length - 1
		if init_in_superclass != null then
			arity = init_in_superclass.signature.arity
		end
		var args = new Array[String].with_capacity(arity + 1)
		args.add(v.cfc.varname(v.nmc.method_params[0]))
		if n_args.length != arity then
			for i in [0..arity[ do
				args.add(v.cfc.varname(v.nmc.method_params[i + 1]))
			end
		else
			for na in n_args do
				args.add(v.compile_expr(na))
			end
		end
		#return "{prop.cname}({args.join(", ")}) /*super {prop.local_class}::{prop.name}*/"
		if init_in_superclass != null then
			return init_in_superclass.intern_compile_call(v, args)
		else
			return prop.compile_super_call(v, args)
		end
	end
end

redef class AAttrExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		return prop.compile_read_access(v, n_id, e)
	end
end

redef class AAttrAssignExpr
	redef fun compile_stmt(v)
	do
		var e = v.compile_expr(n_expr)
		var e2 = v.compile_expr(n_value)
		prop.compile_write_access(v, n_id, e, e2)
	end
end
redef class AAttrReassignExpr
	redef fun compile_stmt(v)
	do
		var e1 = v.compile_expr(n_expr)
		var e2 = prop.compile_read_access(v, n_id, e1)
		var e3 = v.compile_expr(n_value)
		var e4 = assign_method.compile_expr_call(v, [e2, e3])
		prop.compile_write_access(v, n_id, e1, e4)
	end
end

redef class AIssetAttrExpr
	redef fun compile_expr(v)
	do
		var e = v.compile_expr(n_expr)
		return prop.compile_isset(v, n_id, e)
	end
end

redef class AAbsAbsSendExpr
	# Compile each argument and add them to the array
	fun compile_arguments_in(v: CompilerVisitor, cargs: Array[String])
	do
		for a in arguments do
			cargs.add(v.compile_expr(a))
		end
	end

end

redef class ASendExpr
	private fun intern_compile_call(v: CompilerVisitor): nullable String
	do
		var recv = v.compile_expr(n_expr)
		var cargs = new Array[String]
		cargs.add(recv)
		compile_arguments_in(v, cargs)

		var e: nullable String
		if prop_signature.closures.is_empty then
			e = prop.intern_compile_call(v, cargs)
		else
			e = prop.compile_call_and_closures(v, cargs, closure_defs)
		end

		if prop.global.is_init then
			v.invoke_super_init_calls_after(prop)
		end
		return e
	end

	redef fun compile_expr(v)
	do
		var e = intern_compile_call(v)
		assert e != null
		return e
	end

	redef fun compile_stmt(v)
	do
		var e = intern_compile_call(v)
		if e != null then
			v.add_instr(e + ";")
		end
	end
end

redef class ASendReassignExpr
	redef fun compile_expr(v) do abort

	redef fun compile_stmt(v)
	do
		var recv = v.compile_expr(n_expr)
		var cargs = new Array[String]
		cargs.add(recv)
		compile_arguments_in(v, cargs)

		var e2 = read_prop.compile_expr_call(v, cargs)
		var e3 = v.compile_expr(n_value)
		var e4 = assign_method.compile_expr_call(v, [e2, e3])
		cargs.add(e4)
		prop.compile_stmt_call(v, cargs)
	end
end

redef class ANewExpr
	redef fun compile_expr(v)
	do
		var cargs = new Array[String]
		compile_arguments_in(v, cargs)
		return prop.compile_constructor_call(v, stype, cargs)
	end

	redef fun compile_stmt(v) do abort
end

redef class PClosureDef
	# Compile the closure definition as a function in v.out_contexts
	# Return the cname of the function
	fun compile_closure(v: CompilerVisitor, closcn: String): String is abstract

	# Compile the closure definition inside the current C function.
	fun do_compile_inside(v: CompilerVisitor, params: nullable Array[String]): nullable String is abstract
end

redef class AClosureDef
	# The cname of the function
	readable var _cname: nullable String

	redef fun compile_closure(v, closcn)
	do
		var ctx_old = v.ctx
		v.ctx = new CContext
		v.out_contexts.add(v.ctx)

		var cfc_old = v.cfc.closure
		v.cfc.closure = v.nmc

		var old_rv = v.nmc.return_value
		var old_bv = v.nmc.break_value
		if cfc_old == null then
			v.nmc.return_value = "closctx->{old_rv}"
			v.nmc.break_value = "closctx->{old_bv}"
		end

		var cname = "OC_{v.nmc.method.cname}_{v.out_contexts.length}"
		_cname = cname
		var args = new Array[String]
		for i in [0..closure.signature.arity[ do
			args.add(" param{i}")
		end

		var cs = decl_csignature(v, args, closcn)

		v.add_instr("{cs} \{")
		v.indent
		var ctx_old2 = v.ctx
		v.ctx = new CContext

		v.add_decl("struct trace_t trace = \{NULL, NULL, {line_number}, LOCATE_{v.nmc.method.cname}};")
		v.add_instr("trace.prev = tracehead; tracehead = &trace;")
		
		v.add_instr("trace.file = LOCATE_{v.module.name};")
		var s = do_compile_inside(v, args)

		v.add_instr("{v.nmc.return_label}:")
		v.add_instr("tracehead = trace.prev;")
		if s == null then
			v.add_instr("return;")
		else
			v.add_instr("return {s};")
		end

		ctx_old2.append(v.ctx)
		v.ctx = ctx_old2
		v.unindent
		v.add_instr("}")
		v.ctx = ctx_old

		v.cfc.closure = cfc_old
		v.nmc.return_value = old_rv
		v.nmc.break_value = old_bv

		# Build closure
		var closcnv = "wbclos{v.new_number}"
		v.add_decl("struct WBT_ {closcnv};")
		v.add_instr("{closcnv}.fun = (fun_t){cname};")
		v.add_instr("{closcnv}.has_broke = NULL;")
		if cfc_old != null then 
			v.add_instr("{closcnv}.variable = closctx->variable;")
			v.add_instr("{closcnv}.closurevariable = closctx->closurevariable;")
		else
			v.add_instr("{closcnv}.variable = variable;")
			v.add_instr("{closcnv}.closurevariable = closurevariable;")
		end

		return "(&{closcnv})"
	end

	protected fun decl_csignature(v: CompilerVisitor, args: Array[String], closcn: String): String
	do
		var params = new Array[String]
		params.add("struct WBT_ *closctx")
		for i in [0..closure.signature.arity[ do
			var p = "val_t {args[i]}"
			params.add(p)
		end
		var ret: String
		if closure.signature.return_type != null then
			ret = "val_t"
		else
			ret = "void"
		end
		var p = params.join(", ")
		var s = "{ret} {cname}({p})"
		v.add_decl("typedef {ret} (* {cname}_t)({p});")
		v.add_decl(s + ";")
		return s
	end

	redef fun do_compile_inside(v, params)
	do
		for i in [0..variables.length[ do
			var vacname = v.cfc.register_variable(variables[i])
			v.add_assignment(vacname, params[i])
		end

		var old_cv = v.nmc.continue_value
		var old_cl = v.nmc.continue_label
		var old_bl = v.nmc.break_label

		v.nmc.continue_value = v.cfc.get_var("Continue value and escape marker")
		v.nmc.continue_label = "continue_label{v.new_number}"
		v.nmc.break_label = v.nmc.return_label

		v.compile_stmt(n_expr)

		v.add_instr("{v.nmc.continue_label}: while(false);")

		var ret: nullable String = null
		if closure.signature.return_type != null then ret = v.nmc.continue_value

		v.nmc.continue_value = old_cv
		v.nmc.continue_label = old_cl
		v.nmc.break_label = old_bl

		return ret
	end
end

redef class PClosureDecl
	fun do_compile_inside(v: CompilerVisitor, params: Array[String]): nullable String is abstract
end
redef class AClosureDecl
	redef fun do_compile_inside(v, params)
	do
		n_signature.compile_parameters(v, variable.closure.signature, params)

		var old_cv = v.nmc.continue_value
		var old_cl = v.nmc.continue_label
		var old_bl = v.nmc.break_label

		v.nmc.continue_value = v.cfc.get_var("Continue value and escape marker")
		v.nmc.continue_label = "continue_label{v.new_number}"
		v.nmc.break_label = v.nmc.return_label

		v.compile_stmt(n_expr)

		v.add_instr("{v.nmc.continue_label}: while(false);")

		var ret: nullable String = null
		if variable.closure.signature.return_type != null then ret = v.nmc.continue_value

		v.nmc.continue_value = old_cv
		v.nmc.continue_label = old_cl
		v.nmc.break_label = old_bl

		return ret
	end
end

redef class AClosureCallExpr
	fun intern_compile_call(v: CompilerVisitor): nullable String
	do
		var cargs = new Array[String]
		compile_arguments_in(v, cargs)
		var va: nullable String = null
		if variable.closure.signature.return_type != null then va = v.cfc.get_var("Closure call result value")

		if variable.closure.is_optional then
			v.add_instr("if({v.cfc.varname(variable)}==NULL) \{")
			v.indent
			var n = variable.decl
			assert n isa AClosureDecl
			var s = n.do_compile_inside(v, cargs)
			if s != null then v.add_assignment(va.as(not null), s)
			v.unindent
			v.add_instr("} else \{")
			v.indent
		end

		var ivar = v.cfc.varname(variable)
		var cargs2 = [ivar]
		cargs2.append(cargs)
		var s = "(({variable.ctypename})({ivar}->fun))({cargs2.join(", ")}) /* Invoke closure {variable} */"
		if va != null then
			v.add_assignment(va, s)
		else
			v.add_instr("{s};")
		end
		v.add_instr("if ({ivar}->has_broke) \{")
		v.indent
		if n_closure_defs.length == 1 then do
			n_closure_defs.first.do_compile_inside(v, null)
		end
		if v.cfc.closure == v.nmc then v.add_instr("if ({ivar}->has_broke) \{ closctx->has_broke = {ivar}->has_broke; closctx->broke_value = {ivar}->broke_value;\}")
		v.add_instr("goto {v.nmc.return_label};")
		v.unindent
		v.add_instr("\}")

		if variable.closure.is_optional then
			v.unindent
			v.add_instr("\}")
		end
		return va
	end

	redef fun compile_expr(v)
	do
		var e = intern_compile_call(v)
		assert e != null
		return e
	end

	redef fun compile_stmt(v)
	do
		var e = intern_compile_call(v)
		if e != null then
			v.add_instr(e + ";")
		end
	end
end

redef class AProxyExpr
	redef fun compile_expr(v)
	do
		return v.compile_expr(n_expr)
	end
end

redef class AOnceExpr
	redef fun compile_expr(v)
	do
		var i = v.new_number
		var cvar = v.cfc.get_var("Once expression result")
		v.add_decl("static val_t once_value_{i}; static int once_bool_{i}; /* Once value for {cvar}*/")
		v.add_instr("if (once_bool_{i}) {cvar} = once_value_{i};")
		v.add_instr("else \{")
		v.indent
		v.cfc.free_var(cvar)
		var e = v.compile_expr(n_expr)
		v.add_assignment(cvar, e)
		v.add_instr("once_value_{i} = {cvar};")
		v.add_instr("once_bool_{i} = true;")
		v.unindent
		v.add_instr("}")
		return cvar
	end
end

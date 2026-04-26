using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Student
{
    public int EducationalPersonId { get; set; }

    public int BirthUbigeoId { get; set; }

    public bool HasDisability { get; set; }

    public short? Siblings { get; set; }

    public int? ChildbirthTypeId { get; set; }

    public virtual Ubigeo BirthUbigeo { get; set; } = null!;

    public virtual ChildbirthType? ChildbirthType { get; set; }

    public virtual Disability? Disability { get; set; }

    public virtual EducationalPerson EducationalPerson { get; set; } = null!;

    public virtual ICollection<FamiliarStudentRelationship> FamiliarStudentRelationships { get; set; } = new List<FamiliarStudentRelationship>();

    public virtual StudentHome? StudentHome { get; set; }
}
